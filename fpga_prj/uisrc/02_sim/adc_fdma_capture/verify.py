"""Offline capture controller + decoder + real GDB export interoperability checks.
No debug server, target connection, PL programming or board execution is used.
"""
from pathlib import Path
import argparse
import csv
import json
import subprocess
import sys
import zlib


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host-gcc", default="D:/programs/mingw/bin/gcc.exe")
    parser.add_argument("--fd-root", type=Path, default=Path("E:/anlu/FD"))
    args = parser.parse_args()
    tests = Path(__file__).resolve().parent
    app = tests.parents[1] / "07_software/adc_fdma_capture"
    out = app / "build/verification"
    out.mkdir(parents=True, exist_ok=True)
    transcript = []

    def run(command):
        result = subprocess.run([str(x) for x in command], capture_output=True, text=True,
                                encoding="utf-8", errors="replace")
        transcript.append("COMMAND: " + subprocess.list2cmdline([str(x) for x in command]))
        transcript.append(result.stdout + result.stderr)
        if result.returncode:
            raise RuntimeError(f"offline check failed ({result.returncode}): {command[0]}")
        return result.stdout + result.stderr

    try:
        run([args.host_gcc, "-std=c11", "-O2", "-Wall", "-Wextra", "-Werror",
             "-I", app, app / "capture.c", tests / "test_capture.c", "-o", out / "test_capture.exe"])
        host_log = run([out / "test_capture.exe"])
        assert "CAPTURE_HOST_CONTROLLER_ALL_PASS" in host_log
        decoder_log = run([sys.executable, tests / "test_decode.py"])
        assert "Ran 10 tests" in decoder_log and "OK" in decoder_log
        source = '''#include "capture.h"
uint8_t g_capture_buffer[8192] __attribute__((section(".data"),aligned(4096)))={0};
volatile CaptureInfo g_capture_info={.magic=CAPTURE_MAGIC,.version=1,.info_bytes=128,
 .buffer_address=(uintptr_t)g_capture_buffer,.buffer_capacity=8192,.valid_bytes=8192,
 .sample_rate_hz=25000,.ring_slots=2,.completed_blocks=2,.output_before=2,.output_after=2,
 .fdma_status=20,.phase=PHASE,.result=RESULT,.elapsed_ms=21,.payload_format=0x50343831,
 .adc_id=0x41444331,.fdma_id=0x46444d31,.flags=3,.sample_count=512,.crc32=CRC};
void capture_complete(void) {}
'''.replace("CRC}", str(zlib.crc32(bytes(8192))) + "}")
        gcc = args.fd_root / "toolchain/gcc/aarch64/bin/aarch64-none-elf-gcc.exe"
        gdb = args.fd_root / "toolchain/gcc/aarch64/bin/aarch64-none-elf-gdb.exe"
        for name, phase, code in [("success", 3, 0), ("failed", 4, 8)]:
            fixture = out / f"synthetic_{name}_fixture.c"
            fixture.write_text(source.replace("PHASE", str(phase)).replace("RESULT", str(code)))
            elf = fixture.with_suffix(".elf")
            run([gcc, "-g", "-nostdlib", "-I", app, "-Wl,-Ttext=0x08000000",
                 "-Wl,-e,capture_complete", fixture, "-o", elf])
            data, meta = out / f"synthetic_{name}.bin", out / f"synthetic_{name}.meta.bin"
            for path in [data, meta]:
                assert path.resolve().parent == out.resolve()
                if path.exists():
                    path.unlink()  # Only named, synthetic files owned by this check.
            command = [gdb, "-batch", "-ex", "file " + elf.as_posix(),
                       "-ex", "source " + (app / "export_capture.gdb").as_posix(),
                       "-ex", "capture_export " + data.as_posix() + " " + meta.as_posix()]
            log = run(command)
            if name == "success":
                assert data.read_bytes() == bytes(8192) and meta.stat().st_size == 128
                assert "Exported P481" in log
            else:
                assert "REFUSED" in log and not data.exists() and not meta.exists()
        run([sys.executable, app / "decode_p481.py", out / "synthetic_success.bin",
             "--metadata", out / "synthetic_success.meta.bin",
             "--output", out / "synthetic_decoded.csv", "--run-id", "synthetic_protocol_only", "--force"])
        with (out / "synthetic_decoded.csv").open(newline="") as f:
            rows = list(csv.DictReader(f))
        assert len(rows) == 512 and {r["class_id"] for r in rows} == {"-1"}
        report = json.loads((out / "synthetic_decoded.json").read_text())
        assert report["metadata"]["sample_count"] == 512
        summary = {"host_controller": "PASS", "decoder_unittests": 10,
                   "gdb_valid_export": "PASS", "gdb_failed_export_refused": "PASS",
                   "gdb_to_decoder_roundtrip": "PASS",
                   "scope": "SYNTHETIC/OFFLINE ONLY. No hardware or training samples."}
        (out / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
        print("CAPTURE_OFFLINE_VERIFY_ALL_PASS (synthetic only, no board)")
    finally:
        (out / "verification.log").write_text("\n".join(transcript), encoding="utf-8")


if __name__ == "__main__":
    main()
