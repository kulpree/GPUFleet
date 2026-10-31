"""LoRA fine-tuning for the RAG answer model, with metrics pushed to Pushgateway.

Fine-tuning is optional. Start with retrieval and prompt tuning. Run this only when
evaluation shows the base model still answers in the wrong style or language.

Input: JSONL with {"messages": [{"role": "user", ...}, {"role": "assistant", ...}]}
Output: LoRA adapter in OUTPUT_DIR (small; upload it to the bucket under models/).

Environment:
  BASE_MODEL          e.g. Qwen/Qwen2.5-7B-Instruct
  TRAIN_FILE          path to the JSONL training file
  OUTPUT_DIR          where checkpoints and the adapter are written
  RUN_NAME            label for metrics, e.g. "lora-2026-11-02"
  PUSHGATEWAY_URL     e.g. http://prometheus-pushgateway.monitoring.svc:9091
"""

from __future__ import annotations

import os

import torch
from datasets import load_dataset
from peft import LoraConfig, get_peft_model
from prometheus_client import CollectorRegistry, Gauge, push_to_gateway
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    Trainer,
    TrainerCallback,
    TrainingArguments,
)

BASE_MODEL = os.environ["BASE_MODEL"]
TRAIN_FILE = os.environ["TRAIN_FILE"]
OUTPUT_DIR = os.environ.get("OUTPUT_DIR", "/work/output")
RUN_NAME = os.environ.get("RUN_NAME", "lora-run")
PUSHGATEWAY_URL = os.environ.get("PUSHGATEWAY_URL")

registry = CollectorRegistry()
LOSS = Gauge("srag_train_loss", "Training loss", ["run"], registry=registry)
STEP = Gauge("srag_train_step", "Current optimizer step", ["run"], registry=registry)
TPS = Gauge("srag_train_tokens_per_second", "Training throughput", ["run"], registry=registry)
CKPT = Gauge(
    "srag_train_last_checkpoint_timestamp", "Unix time of last checkpoint", ["run"], registry=registry
)


def push() -> None:
    if PUSHGATEWAY_URL:
        push_to_gateway(PUSHGATEWAY_URL, job=RUN_NAME, registry=registry)


class MetricsCallback(TrainerCallback):
    """Pushes loss, step, and throughput to Pushgateway at each logging step."""

    def on_log(self, args, state, control, logs=None, **kwargs):
        if not logs:
            return
        if "loss" in logs:
            LOSS.labels(run=RUN_NAME).set(logs["loss"])
        if "train_steps_per_second" in logs and "train_samples_per_second" in logs:
            TPS.labels(run=RUN_NAME).set(logs["train_samples_per_second"])
        STEP.labels(run=RUN_NAME).set(state.global_step)
        push()

    def on_save(self, args, state, control, **kwargs):
        import time

        CKPT.labels(run=RUN_NAME).set(time.time())
        push()


def main() -> None:
    tokenizer = AutoTokenizer.from_pretrained(BASE_MODEL)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    model = AutoModelForCausalLM.from_pretrained(
        BASE_MODEL, torch_dtype=torch.bfloat16, device_map="auto"
    )
    model = get_peft_model(
        model,
        LoraConfig(
            r=16,
            lora_alpha=32,
            lora_dropout=0.05,
            target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],
            task_type="CAUSAL_LM",
        ),
    )
    model.print_trainable_parameters()

    dataset = load_dataset("json", data_files=TRAIN_FILE, split="train")

    def tokenize(example):
        text = tokenizer.apply_chat_template(example["messages"], tokenize=False)
        encoded = tokenizer(text, truncation=True, max_length=2048)
        # Causal LM: labels are the input ids. The model shifts them internally.
        encoded["labels"] = list(encoded["input_ids"])
        return encoded

    dataset = dataset.map(tokenize, remove_columns=dataset.column_names)

    args = TrainingArguments(
        output_dir=OUTPUT_DIR,
        per_device_train_batch_size=2,
        gradient_accumulation_steps=8,
        learning_rate=2e-4,
        num_train_epochs=2,
        lr_scheduler_type="cosine",
        warmup_ratio=0.03,
        bf16=True,
        logging_steps=10,
        save_steps=200,
        save_total_limit=2,          # keep disk use low
        report_to="none",
    )

    trainer = Trainer(
        model=model,
        args=args,
        train_dataset=dataset,
        data_collator=lambda batch: tokenizer.pad(batch, return_tensors="pt"),
        callbacks=[MetricsCallback()],
    )
    trainer.train()

    model.save_pretrained(os.path.join(OUTPUT_DIR, "adapter"))
    tokenizer.save_pretrained(os.path.join(OUTPUT_DIR, "adapter"))
    push()


if __name__ == "__main__":
    main()
