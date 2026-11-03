"""Synthetic protocol fixtures only; these are not power-stage training data."""
from pathlib import Path
import csv
import importlib.util
import uuid
import unittest
import zlib

APP = Path(__file__).resolve().parents[2] / "07_software/adc_fdma_capture"
spec = importlib.util.spec_from_file_location("decode_p481", APP / "decode_p481.py")
decoder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(decoder)


class DecoderTests(unittest.TestCase):
    def setUp(self):
        # Scope temporary files to this workspace, not a user data directory.
        # Normal mkdir preserves inherited Windows workspace ACLs. Some
        # Python/Windows runtimes make mkdtemp(mode=0700) inaccessible here.
        self.root = Path(__file__).parent / ("synthetic_" + uuid.uuid4().hex)
        self.root.mkdir()
        def cleanup():
            assert self.root.resolve().parent == Path(__file__).resolve().parent
            for path in self.root.iterdir():
                path.unlink()  # Fixtures are flat; never recursively delete.
            self.root.rmdir()
        self.addCleanup(cleanup)
        self.data = self.root / "synthetic.bin"
        self.meta = self.root / "synthetic.meta.bin"
        frame = ((-131072).to_bytes(6, "little", signed=True) +
                 (98304).to_bytes(6, "little", signed=True) + (32768).to_bytes(4, "little"))
        self.raw = frame * 512
        self.data.write_bytes(self.raw)
        self.info = dict.fromkeys(decoder.FIELDS, 0)
        self.info.update(magic=decoder.CAP1, version=1, info_bytes=128, result=0,
                         buffer_address=0x08000000, buffer_capacity=8192, valid_bytes=8192,
                         sample_rate_hz=25000, ring_slots=2, completed_blocks=2,
                         output_before=2, output_after=2, fdma_status=20, phase=3,
                         elapsed_ms=21, payload_format=decoder.P481, adc_id=0x41444331,
                         fdma_id=0x46444d31, flags=3, sample_count=512,
                         crc32=zlib.crc32(self.raw))
        self.write_info()

    def write_info(self):
        self.meta.write_bytes(decoder.LAYOUT.pack(*(self.info[k] for k in decoder.FIELDS)))

    def convert(self, **kwargs):
        return decoder.convert(self.data, self.meta, self.root / "out.csv", "synthetic-test", **kwargs)

    def test_physical_values_unknown_labels(self):
        report = self.convert()
        with (self.root / "out.csv").open(newline="") as f:
            rows = list(csv.DictReader(f))
        self.assertEqual(len(rows), 512)
        self.assertEqual([float(rows[0][k]) for k in ("vout_v", "iout_a", "duty")], [-2, 1.5, 0.5])
        self.assertEqual(rows[0]["class_id"], "-1")
        self.assertEqual(report["label_counts"][-1], 512)

    def test_signed48_extremes(self):
        for x in [-(1 << 47), -1, 0, (1 << 47) - 1]:
            raw = x.to_bytes(6, "little", signed=True) * 2 + (65536).to_bytes(4, "little")
            self.assertEqual(decoder.decode_frame(raw), (x, x, 65536))

    def test_interval_labels_and_unknown_gaps(self):
        labels = self.root / "labels.csv"
        labels.write_text("start_sample,end_sample,class_id\n0,100,0\n100,200,1\n300,512,2\n")
        report = self.convert(labels=labels)
        self.assertEqual(report["label_counts"], {-1: 100, 0: 100, 1: 100, 2: 212})

    def test_overlapping_intervals_rejected(self):
        labels = self.root / "labels.csv"
        labels.write_text("start_sample,end_sample,class_id\n0,200,0\n100,300,1\n")
        with self.assertRaisesRegex(ValueError, "overlap"):
            self.convert(labels=labels)

    def test_metadata_rejections(self):
        for field, value in [("magic", 0), ("version", 99), ("result", 8), ("phase", 5),
                             ("flags", 1), ("payload_format", 0), ("completed_blocks", 1),
                             ("consumer", 1), ("drop_end", 1), ("fdma_error", 2),
                             ("fdma_status", 18), ("sample_rate_hz", 0), ("sample_count", 1)]:
            with self.subTest(field=field):
                old = self.info[field]
                self.info[field] = value
                self.write_info()
                with self.assertRaises(ValueError):
                    self.convert()
                self.info[field] = old
        self.write_info()

    def test_crc_mismatch(self):
        self.data.write_bytes(bytes([self.raw[0] ^ 1]) + self.raw[1:])
        with self.assertRaisesRegex(ValueError, "CRC32"):
            self.convert()

    def test_truncated_payload(self):
        self.data.write_bytes(self.raw[:-16])
        with self.assertRaisesRegex(ValueError, "length"):
            self.convert()

    def test_bad_duty_even_with_correct_crc(self):
        raw = self.raw[:12] + (65537).to_bytes(4, "little") + self.raw[16:]
        self.data.write_bytes(raw)
        self.info["crc32"] = zlib.crc32(raw)
        self.write_info()
        with self.assertRaisesRegex(ValueError, "duty"):
            self.convert()
        self.assertFalse((self.root / "out.csv").exists())

    def test_no_accidental_overwrite(self):
        self.convert(label="normal")
        with self.assertRaisesRegex(ValueError, "exists"):
            self.convert()

    def test_short_metadata(self):
        self.meta.write_bytes(b"CAP1")
        with self.assertRaisesRegex(ValueError, "128"):
            self.convert()


if __name__ == "__main__":
    unittest.main(verbosity=2)
