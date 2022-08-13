#!/usr/bin/env bash

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
  mnt="$PWD"
  mntc=$mnt
  user=`echo $mnt | grep -o '/home/[^/]*'` # User's $HOME
  # If you're root, replace every occurence of $HOME with /root
  if [[ $USER == "root" ]]; then
    mntc=`sed "s!$user!$HOME!g"<<<"$mnt"`
  fi
  opt=" --bind $mnt:$mntc"
  # If you're trying to mount home directory, don't
  if [[ $mnt == $user ]]; then
    opt=""
  fi
  echo $opt
}

function bind_home() {
  cache=$1
  user=`echo $PWD | grep -o '/home/[^/]*'` # User's $HOME
  opt=""
  if [[ $USER == "root" ]]; then
    opt=" --home $cache/root:/root"
    opt+=" --bind $user/.ssh:/root/.ssh"
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
  singularity shell \
    $(default_options) \
    $(bind_home $cache) \
    $(bind_pwd $cache) \
    $image_path
}

function run_exec() {
  image_path=$1
  cache=$(make_cache $image_path)
  cmd_exec=${@:2}
  echo "Executing \"$cmd_exec\" in $(basename $image_path)"
  singularity exec \
    $(default_options) \
    $(bind_home $cache) \
    $(bind_pwd $cache) \
    $image_path \
    /bin/bash -c "$cmd_exec"
}
