#!/bin/bash

target="/tmp/target_image.bin"
trace="/tmp/target_trace.txt"
all=0
pass=0
for elf in ./testbin/*.elf; do
  all=$((all+1))
  riscv64-linux-gnu-objcopy -Obinary -R .tohost -R .fromhost $elf $target
  make run-trace MAX_CYCLE=1000 IMAGE=$target DUMP=0 &> $trace
  if grep 'output: ' $trace &> /dev/null; then
    result="OK"
    pass=$((pass+1))
  else
    ngtrace="`dirname $trace`/NG-`basename $elf`.dump"
    mv $trace $ngtrace
    result="NG -> $ngtrace"
  fi
  printf "%30s | ${result}\n" `basename $elf`
done

echo "$pass / $all"
