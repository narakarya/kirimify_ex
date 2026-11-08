# kirimify_ex

Library Elixir (bukan aplikasi Phoenix): klien + verifier webhook untuk API WhatsApp Kirimify. Dibagikan lewat Git (`github: "narakarya/kirimify_ex", tag:`), bukan Hex. Deps: Req, Jason, Plug. Tidak ada Tidewave/AGENTS.md.

## Validasi
- `.claude/validate.sh` (non-mutating: compile --warnings-as-errors, format --check-formatted, deps.unlock --check-unused, test; hanya jalan bila lib/test/config/priv/mix.exs/mix.lock berubah, `FORCE=1` untuk paksa). Jalankan dari dalam repo.
- Tidak ada alias `precommit`. Terakhir dijalankan: 14 tes hijau.

## Test
- Tidak butuh DB atau jaringan.

## Gotcha
- Pengiriman pesan asinkron: `send_text/4` mengembalikan 202 `queued`; status akhir hanya lewat webhook.
- `@version` di mix.exs (0.1.1) bisa lebih baru dari tag yang disebut di README (v0.1.0); jangan ubah tanpa diminta.
