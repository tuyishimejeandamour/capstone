"""Factory helpers for Hugging Face generation during evaluation."""

from __future__ import annotations

from typing import Any, Callable


def make_generate_fn(model, tokenizer) -> Callable[..., str]:
    template_kwargs = {"enable_thinking": False}

    def generate_fn(
        *,
        messages: list[dict[str, Any]],
        tools: list[dict[str, Any]],
        max_new_tokens: int = 256,
    ) -> str:
        try:
            inputs = tokenizer.apply_chat_template(
                messages,
                tools=tools,
                add_generation_prompt=True,
                return_dict=True,
                return_tensors="pt",
                **template_kwargs,
            )
        except TypeError:
            inputs = tokenizer.apply_chat_template(
                messages,
                tools=tools,
                add_generation_prompt=True,
                return_dict=True,
                return_tensors="pt",
            )
        device = getattr(model, "device", None)
        if device is not None:
            inputs = inputs.to(device)
        outputs = model.generate(
            **inputs,
            max_new_tokens=max_new_tokens,
            do_sample=False,
            pad_token_id=tokenizer.eos_token_id,
        )
        prompt_len = inputs["input_ids"].shape[-1]
        return tokenizer.decode(outputs[0][prompt_len:], skip_special_tokens=False)

    return generate_fn
