#!/bin/bash

target="/tmp/target_image.bin"
all=0
pass=0
for elf in ./testbin/*.elf; do
  all=$((all+1))
  riscv64-linux-gnu-objcopy -Obinary -R .tohost -R .fromhost $elf $target
  trace="`dirname $target`/`basename $elf`.trace"
  make run-trace MAX_CYCLE=500 IMAGE=$target DUMP=0 &> $trace
  if grep -q 'output: ' $trace && grep -q 'Abort' $trace; then
    result="OK"
    pass=$((pass+1))
    #rm $trace
  else
    result="NG -> $trace"
  fi
  printf "%30s | ${result}\n" `basename $elf`
done

echo "$pass / $all"
