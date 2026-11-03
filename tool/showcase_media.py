#!/usr/bin/env python3
"""Edit the reviewed November gallery or portrait water capture."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

MASTER = [(2, 5), (10.5, 17.5), (23.2, 31.7), (33.4, 38),
          (38.5, 44.5), (53, 59.5), (83, 87.5)]
GIF = [(2, 3.2), (10.8, 15.6), (33.4, 38), (83, 84.2)]
WATER_MASTER = [(2.4, 26.4)]
WATER_GIF = [(3.4, 13.4)]


def run(*args):
    subprocess.run(args, check=True)


def probe(path):
    return json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_format', '-show_streams',
        '-of', 'json', str(path)], text=True))


def validate_cuts(cuts, duration):
    previous = 0
    for start, end in cuts:
        if not 0 <= previous <= start < end <= duration:
            raise ValueError('Cuts must be ordered, non-overlapping, and inside the capture.')
        previous = end


def edit(source, cuts, destination, scratch, prefix):
    parts = []
    for index, (start, end) in enumerate(cuts):
        part = scratch / f'{prefix}-{index}.mp4'
        run('ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
            '-ss', str(start), '-i', str(source), '-t', str(end - start),
            '-an', '-c:v', 'libx264', '-preset', 'medium', '-crf', '18',
            '-pix_fmt', 'yuv420p', '-r', '30', str(part))
        parts.append(part)
    manifest = scratch / f'{prefix}.txt'
    # Only generated filenames enter the concat manifest.
    manifest.write_text(''.join(f"file '{p.name}'\n" for p in parts))
    run('ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
        '-f', 'concat', '-safe', '1', '-i', str(manifest),
        '-c', 'copy', '-movflags', '+faststart', str(destination))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--output', type=Path, default=Path('assets/showcase'))
    parser.add_argument('--water', action='store_true',
                        help='Use the reviewed 494×960 portrait Linux water take.')
    args = parser.parse_args()
    master_cuts = WATER_MASTER if args.water else MASTER
    gif_cuts = WATER_GIF if args.water else GIF
    name = 'nibmotion-water' if args.water else 'nibmotion-showcase'
    if not args.capture.is_file():
        parser.error('Capture must be an existing video file.')
    for command in ('ffmpeg', 'ffprobe'):
        if not shutil.which(command):
            parser.error(f'{command} is required.')
    source_info = probe(args.capture)
    duration = float(source_info['format']['duration'])
    validate_cuts(master_cuts, duration)
    validate_cuts(gif_cuts, duration)
    video = next(s for s in source_info['streams'] if s['codec_type'] == 'video')
    expected = (494, 960) if args.water else (1920, 1080)
    if (video['width'], video['height']) != expected:
        parser.error(f'This edit expects the reviewed {expected} capture.')
    args.output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='nib-showcase-') as folder:
        scratch = Path(folder)
        master = scratch / f'{name}.mp4'
        gif_source = scratch / 'gif-source.mp4'
        gif = scratch / f'{name}.gif'
        poster = scratch / ('nibmotion-water-poster.png' if args.water else 'nibmotion-poster.png')
        edit(args.capture, master_cuts, master, scratch, 'master')
        edit(args.capture, gif_cuts, gif_source, scratch, 'gif')
        gif_filter = 'fps=12,scale=300:-2' if args.water else 'fps=18,scale=960:-2'
        run('ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
            '-i', str(gif_source), '-filter_complex',
            gif_filter + ':flags=lanczos,split[a][b];'
            '[a]palettegen=stats_mode=diff[p];'
            '[b][p]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle',
            '-loop', '0', str(gif))
        run('ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
            '-ss', '2', '-i', str(args.capture), '-frames:v', '1', str(poster))
        if gif.stat().st_size >= 4_000_000:
            raise ValueError(f'GIF is {gif.stat().st_size:,} bytes; revise the edit to stay below 4 MB.')
        metadata = {'source_sha256': hashlib.sha256(args.capture.read_bytes()).hexdigest(),
                    'master_cuts_seconds': master_cuts, 'gif_cuts_seconds': gif_cuts,
                    'capture': ('Actual Flutter Linux app, Impeller, wf-recorder, 494×960 portrait crop, 30 FPS'
                                if args.water else 'Actual Flutter app, wf-recorder, 1920×1080, 30 FPS'),
                    'assets': {}}
        for asset in (master, gif, poster):
            run('ffmpeg', '-hide_banner', '-loglevel', 'error', '-i', str(asset),
                '-f', 'null', '-')
            info = probe(asset)
            stream = info['streams'][0]
            metadata['assets'][asset.name] = {
                'bytes': asset.stat().st_size, 'codec': stream['codec_name'],
                'width': stream['width'], 'height': stream['height'],
                'duration': info['format'].get('duration'),
                'frame_rate': stream.get('avg_frame_rate'),
                'sha256': hashlib.sha256(asset.read_bytes()).hexdigest()}
            shutil.copy2(asset, args.output / asset.name)
        (args.output / ('water-metadata.json' if args.water else 'metadata.json')).write_text(json.dumps(metadata, indent=2) + '\n')
        print(json.dumps(metadata, indent=2))


if __name__ == '__main__':
    main()
