#!/bin/bash

all=0
pass=0
for elf in ./testbin/*.elf; do
  all=$((all+1))
  target="/tmp/`basename $elf`.bin"
  trace="`dirname $target`/`basename $elf`.trace"
  riscv64-linux-gnu-objcopy -Obinary -R .tohost -R .fromhost $elf ${target}_
  dd status=none if=/dev/zero bs=512k count=1 >> ${target}_
  dd status=none if=${target}_ bs=512k count=1 > ${target}
  make run-trace MAX_CYCLE=1000 IMAGE=$target DUMP=0 &> $trace
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
