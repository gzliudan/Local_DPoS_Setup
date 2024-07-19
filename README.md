# Guide

This document explains how to sync xdc networks.

## 1. start sync

### 1.1 start instance with default config

#### 1.1.1 mainnet

```bash
./sync-xinfin.sh
```

#### 1.1.2 testnet

```bash
./sync-apothem.sh
```

#### 1.1.3 devnet

```bash
./sync-devnet.sh
```

### 1.2 start instances with custom config

#### 1.2.1 mainnet

create a config file, such as:

```text
PORT=30504
RPC_PORT=8546
WS_PORT=9546
XDC_SRC="/home/me/XDPoSChain2"
DATA_DIR="/home/me/xdc_data/xinfin2"
```

Then start instance with your config file:

```bash
./sync-xinfin.sh <CONFIG_FILE_NAME>
```

#### 1.2.2 testnet

create a config file, such as:

```text
PORT=30604
RPC_PORT=8646
WS_PORT=9646
XDC_SRC="/home/me/XDPoSChain3"
DATA_DIR="/home/me/xdc_data/apothem3"
```

Then start instance with your config file:

```bash
./sync-apothem.sh <CONFIG_FILE_NAME>
```

##### 1.2.3 devnet

create a config file, such as:

```text
PORT=30704
RPC_PORT=8746
WS_PORT=9746
XDC_SRC="/home/me/XDPoSChain4"
DATA_DIR="/home/me/xdc_data/devnet4"
```

Then start instance with your config file:

```bash
./sync-devnet.sh <CONFIG_FILE_NAME>
```

## 2. stop sync

### 2.1 stop all instances

```bash
./stop-all-sync.sh
```

### 2.2 stop one instance

```bash
./stop-sync-by-pid.sh <PID_FILE>
```
