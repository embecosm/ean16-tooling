# ExecuTorch on a CORE-V microcontroller

## Prerequisites

These are all written for Ubuntu 24.04. Other versions of Linux will be very
similar.

### The general build tools

```
sudo apt install build-essential
```

### The Ninja build system

```
sudo apt install ninja-build
```

### The Verilator modeling tool

```
sudo apt install verilator
```

This version of Verilator may not be new enough, in which case follow the
instructions on the [Veripool website](https://www.veripool.org/verilator/) to
download and build from source.  Version 5.042 was used in preparing this
workshop.

## Tooling repository

Start by downloading the `tooling` repository.  For HTTPS users:
```
git clone https://github.com/embecosm/ean16-tooling.git tooling
```
For SSH users:
```
git clone git@github.com:embecosm/ean16-tooling.git tooling
```


### Other repositories

Change to the `tooling` repository and use the `clone-all.sh` script to obtain
the ExecuTorch repository fork we will be using, and the Verilator of the
CV32E40Pv2 model we will be using to run everything.

```
cd tooling
./clone-all.sh
```

By default this uses HTTPS.  If you would prefer to use SSH (less entering
passwords), use

```
cd tooling
./clone-all.sh --ssh
```

## Prepare the Verilator model

Run the `.build-model.sh` script

```
./build-model.sh
```

(use the `--help` option to see options for building)
