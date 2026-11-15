#!/bin/sh
# deploy.sh [frames_dir]  (run on the Mac)
# Pushes the player scripts + config, and (if given) a frames dir, to the Kindle.
# Frames are tarred and extracted on-device so thousands of files transfer fast.
# Uses password SSH (Jobman's chroot blocks key auth); you'll be prompted.
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
KHOST="${KINDLE_HOST:-root@192.168.1.50}"   # set KINDLE_HOST=root@<your-kindle-ip>
DEST="/mnt/us/vsmp"
FRAMES="$1"

ssh "$KHOST" "mkdir -p $DEST/bin $DEST/frames $DEST/state"
scp "$HERE/config.sh" "$KHOST:$DEST/config.sh"
scp "$HERE"/bin/*.sh  "$KHOST:$DEST/bin/"
ssh "$KHOST" "chmod +x $DEST/bin/*.sh"

if [ -n "$FRAMES" ] && [ -d "$FRAMES" ]; then
  echo "packing frames..."
  ( cd "$FRAMES" && tar czf /tmp/vsmp_frames.tgz frame_*.png )
  scp /tmp/vsmp_frames.tgz "$KHOST:/tmp/vsmp_frames.tgz"
  ssh "$KHOST" "rm -f $DEST/frames/frame_*.png; tar xzf /tmp/vsmp_frames.tgz -C $DEST/frames && rm -f /tmp/vsmp_frames.tgz && ls $DEST/frames | wc -l"
fi
echo "deployed to $KHOST:$DEST"
