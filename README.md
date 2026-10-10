# dt-landing-encoder

Turns raw video uploads from the troszakdamian.com admin into adaptive HLS bundles.

The admin uploads the raw file to the R2 bucket `dt-landing` under `raw/<slug>/`, then starts the `Encode` workflow with the slug.
The workflow runs `encode-hls.sh` (ffmpeg, 360p/720p/1080p), writes the bundle to `hls/<slug>/` and deletes the raw file.
On failure it writes `raw/<slug>/failed`, which the admin shows as an error.

This repo is public so the encodes run on free GitHub Actions minutes.
Run logs are public too, so the workflow prints only the slug and ffmpeg progress.

## Secrets

- `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`: R2 API token with Object Read & Write on `dt-landing`.
- `R2_ENDPOINT`: `https://<account id>.r2.cloudflarestorage.com`.

## Run locally

```bash
./encode-hls.sh input.mov my-slug   # writes out/my-slug/
```
