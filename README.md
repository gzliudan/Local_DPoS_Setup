# Guide

This document explains how to sync xdc networks.

## 1. start sync

### 1.1 start a node with default config

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

Read configuration from <CONFIG_FILE_NAME>:

```bash
./sync-xinfin.sh <CONFIG_FILE_NAME>
```

#### 1.2.2 testnet

Read configuration from <CONFIG_FILE_NAME>:

```bash
./sync-apothem.sh <CONFIG_FILE_NAME>
```

##### 1.2.3 devnet

Read configuration from <CONFIG_FILE_NAME>:

```bash
./sync-devnet.sh <CONFIG_FILE_NAME>
```

## 2. stop sync

### 2.1 stop all nodes

```bash
./stop-all.sh
```

### 2.2 stop one node by PID

```bash
./stop-pid.sh <PID_FILE>
```

### 2.3 stop none node by config

```bash
./stop-cfg.sh <CONFIG_FILE_NAME>
```
