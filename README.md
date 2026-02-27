# ctf-analyzer

A lightweight Docker-based dynamic analysis tool for CTF binaries. Runs `strace` and `ltrace` inside an isolated container and surfaces the most useful findings — program output, files opened, string comparisons, and exec calls — without any noise from the host system.

---

## Motivation

Running `strace` and `ltrace` directly on your host produces noisy output polluted by the host environment. Doing it inside a throw-away Docker container gives you a clean, repeatable environment with no host processes bleeding in, no network access, and nothing left behind when you're done.

---

## Features

- Fully isolated container — `--network none`, all capabilities dropped except `SYS_PTRACE`
- Clean strace and ltrace output with no host noise
- Auto-destroys the container after each run
- Highlights section extracts the most CTF-relevant findings immediately:
  - Program output
  - Files opened
  - **String comparisons** — `strcmp`, `memcmp`, etc. (often reveals flag checks directly)
  - Exec calls
- Full raw logs saved for deeper review

---

## Requirements

- Docker

---

## Installation

```bash
git clone https://github.com/ASYquan/ctf-analyzer.git
cd ctf-analyzer
chmod +x analyze.sh
```

The Docker image is built automatically on first run.

---

## Usage

```bash
./analyze.sh <binary> [args to pass to binary]
```

### Examples

```bash
# Run with no arguments
./analyze.sh ./challenge

# Pass input to the binary
./analyze.sh ./challenge mysecretinput

# Multiple args
./analyze.sh ./challenge arg1 arg2
```

---

## Example Output

```
[+] Starting isolated container...
[+] Running strace...
[+] strace done → ./analysis_challenge_20260227_194140/strace.txt
[+] Running ltrace...
[+] ltrace done → ./analysis_challenge_20260227_194140/ltrace.txt
[+] Container destroyed.

══════════════════════════════════════════════
  HIGHLIGHTS
══════════════════════════════════════════════

── Program output (strace write calls) ───────
Access granted!\n

── Files opened ───────────────────────────────
/lib/x86_64-linux-gnu/libc.so.6

── String comparisons (flag checks!) ─────────
22 [0x55c82592117b] strcmp("secret123", "secret123") = 0

── Exec calls ────────────────────────────────
15    18:41:40.870559 execve("/analysis/challenge", [...], ...) = 0

══════════════════════════════════════════════
  Full output: ./analysis_challenge_20260227_194140/
    strace.txt — all syscalls
    ltrace.txt — all library calls
══════════════════════════════════════════════
```

The string comparison line instantly reveals what value the binary is comparing against — which in CTF challenges is often the flag or password.

---

## Project Structure

```
ctf-analyzer/
├── analyze.sh      # Main analysis script
└── Dockerfile      # Minimal Debian image with strace + ltrace
```

---

## Container Security Flags

| Flag | Purpose |
|---|---|
| `--network none` | No network access |
| `--cap-drop ALL` | Drop all Linux capabilities |
| `--cap-add SYS_PTRACE` | Re-add only what strace/ltrace need |
| `--security-opt no-new-privileges` | Prevent privilege escalation |
| `--memory 256m` | Cap memory usage |
| `--pids-limit 64` | Limit process spawning |

---

## Limitations

- Designed for CTF binaries and known-safe samples
- Docker shares the host kernel — not suitable for executing real malware
- Binaries that detect container environments may behave differently
- Interactive binaries that require stdin are not currently supported

---

## License

For educational and security research purposes only.
