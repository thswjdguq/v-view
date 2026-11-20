"""Build the Cloud Shell source ZIP from an explicit list, without credentials."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
FILES = (
    "README.md", "CLOUD-RUN.md", "Dockerfile", ".dockerignore", ".gcloudignore",
    ".gitignore", ".npmrc", "package.json", "package-lock.json",
    "src/app.js", "src/index.js",
    "scripts/cloud-run-plan.js", "scripts/prepare-cloud-run.js",
    "scripts/package-cloud-run.py", "deploy/cloud-run.example.json",
    "test/app.test.js", "test/cloud_run_plan.test.js",
)


def package():
    sources = []
    for name in FILES:
        path = ROOT / name
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(ROOT):
            raise ValueError(f"Missing or unsafe source file: {name}")
        sources.append((path, f"v-view-server/{name}"))
    output = ROOT.parent / "v_view/build/deployment/v-view-cloud-run-source.zip"
    output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(output, "w", ZIP_DEFLATED) as archive:
        for path, name in sources:
            archive.write(path, name)
    with ZipFile(output) as archive:
        assert archive.testzip() is None
        assert set(archive.namelist()) == {name for _, name in sources}
    print(f"Packaged {len(sources)} source files: {output}")


if __name__ == "__main__":
    package()
