# Guide

This document explains how to sync xdc networks.

## 1. start sync

### 1.1 start a node with default config

The default config file is `cfg1.env` if not specified.

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

### 1.2 start a node with custom config

#### 1.2.1 mainnet

```bash
./sync-xinfin.sh <CONFIG_FILE_NAME>
```

#### 1.2.2 testnet

```bash
./sync-apothem.sh <CONFIG_FILE_NAME>
```

##### 1.2.3 devnet

```bash
./sync-devnet.sh <CONFIG_FILE_NAME>
```

## 2. stop sync

### 2.1 stop one node by config

```bash
./stop-cfg.sh <CONFIG_FILE_NAME>
```

### 2.2 stop one node by PID

```bash
./stop-pid.sh <PID_FILE>
```

### 2.3 stop all nodes

```bash
./stop-all.sh
```
