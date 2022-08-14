#!/usr/bin/env bash

APPTAINER_BIN="apptainer -q"

function make_cache() {
  image_path=$1
  tmp_dir="/home/wankun/.apptainer/run/cache/$(basename $image_path)"
  dirs="$tmp_dir $tmp_dir/root $tmp_dir/home"
  if [[ $USER == "root" ]]; then
    runuser -l wankun -c "mkdir -p $dirs > /dev/null 2>&1"
  else
    mkdir -p $dirs > /dev/null 2>&1
  fi
  echo $tmp_dir
}

function bind_pwd() {
  cache=$1
  myhome=`echo $PWD | grep -o '/home/[^/]*'` # user's $HOME
  if [[ $PWD == $myhome ]]
  then  # don't mount home directory (use cache)
    mnt=""
    target=""
  elif [[ ! -z `echo $PWD | grep -o '/home/[^/]*/[^/]*'` ]]
  then # mount $PWD and parents until just below $HOME
    mnt=`echo $PWD | grep -o '/home/[^/]*/[^/]*'`
    target=$mnt
  else # fall back to mount only $PWD
    mnt="$PWD"
    target=$mnt
  fi
  # If you're root, change $HOME in target to /root
  if [[ $USER == "root" ]]; then
    target=`sed "s!$myhome!$HOME!g"<<<"$mnt"`
  fi
  opt=" --bind $mnt:$target"
  echo $opt
}

function bind_home() {
  cache=$1
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
  opts+=" --nv"
  opts+=" --nvccli"
  if [[ $USER == "root" ]]; then
    opts+=" --writable"
  else
    opts+=" --writable-tmpfs"
  fi
  echo $opts
}

function run_shell() {
  image_path=$1
  cache=$(make_cache $image_path)
  $APPTAINER_BIN shell \
    $(default_options) \
    $(bind_home $cache) \
    $(bind_pwd $cache) \
    $image_path
}

function run_exec() {
  image_path=$1
  cache=$(make_cache $image_path)
  cmd_exec=${@:2}
  # echo "Executing \"$cmd_exec\" in $(basename $image_path)"
  $APPTAINER_BIN exec \
    $(default_options) \
    $(bind_home $cache) \
    $(bind_pwd $cache) \
    $image_path \
    /bin/bash -c "$cmd_exec"
}
