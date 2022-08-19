#!/usr/bin/env bash

APPTAINER=""
if [[ $(command -v apptainer) ]]; then
  APPTAINER='apptainer'
elif [[ $(command -v singularity) ]]; then
  APPTAINER='singularity'
else
  return 1
fi
APPTAINER_OPT='-q'
APPTAINER_BIN="$APPTAINER $APPTAINER_OPT"

NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics,video,display
MAIN_USER=$(who am i | awk '{print $1}')


function replacewith() {
  newpattern=$1
  oldpattern=$2
  input=$3
  echo `sed "s!$oldpattern!$newpattern!g"<<<"$input"`
}

function make_cache() {
  image_path=$1
  tmp_dir="/home/$MAIN_USER/.$APPTAINER/run/cache/$(basename $image_path)"
  dirs="$tmp_dir $tmp_dir/root $tmp_dir/home"
  if [[ $USER == "root" ]]; then
    runuser -l $MAIN_USER -c "mkdir -p $dirs > /dev/null 2>&1"
  else
    mkdir -p $dirs > /dev/null 2>&1
  fi
  echo $tmp_dir
}

function bind_pwd() {
  echo $(bind $PWD)
}

function bind() {
  src=$1
  myhome=`echo $src | grep -o '/home/[^/]*'` # user's $HOME
  if [[ $src == $myhome ]]
  then  # don't mount home directory (use cache)
    mnt=""
    target=""
  elif [[ ! -z `echo $src | grep -o '/home/[^/]*/[^/]*'` ]]
  then # mount $src and parents until just below $HOME
    mnt=`echo $src | grep -o '/home/[^/]*/[^/]*'`
    target=$mnt
  else # fall back to mount only $PWD
    mnt=$src
    target=$mnt
  fi
  # If you're root, change $HOME in target to /root
  if [[ $USER == "root" ]]; then
    target=$(replacewith "/root" $myhome $mnt)
  fi
  opt=" --bind $mnt:$target"
  echo $opt
}

function bind_home() {
  cache=$(make_cache $image_path)
  myhome=`echo $PWD | grep -o '/home/[^/]*'` # user's $HOME
  opt=""
  if [[ $USER == "root" ]]; then
    opt=" --home $cache/root:/root"
    opt+=" --bind $myhome/.ssh:/root/.ssh"
  else
    opt=" --home $cache/home:/home/$USER"
    opt+=" --bind /home/$USER/.ssh:/home/$USER/.ssh"
  fi
  echo $opt
}

function default_options() {
  opts=""
  opts+=" --pid"
  if [[ $(command -v nvidia-smi) ]]; then
    opts+=" --nv"
  fi
  if [[ $(command -v nvidia-container-toolkit) ]]; then
    opts+=" --nvccli"
  fi
  if [[ $USER == "root" ]]; then
    opts+=" --writable"
  else
    opts+=" --writable-tmpfs"
  fi
  echo $opts
}

function run_run() {
  image_path=$1
  $APPTAINER_BIN run \
    $(default_options) \
    $(bind_home) \
    $(bind_pwd) \
    $image_path
}

function run_shell() {
  image_path=$1
  $APPTAINER_BIN shell \
    $(default_options) \
    $(bind_home) \
    $(bind_pwd) \
    $image_path
}

function run_exec() {
  image_path=$1
  cmd_exec=${@:2}
  $APPTAINER_BIN exec \
    $(default_options) \
    $(bind_home) \
    $(bind_pwd) \
    $image_path \
    /bin/bash -c "$cmd_exec"
}
