# How to setup private network for XDC blockchain

References: https://medium.com/xinfin/how-to-set-up-a-private-blockchain-network-with-xdc-network-codebase-b2ee82368e83

## 1. Install latest golang

Please refer to [the install page](https://go.dev/doc/install). Remember to set environment variables `GOPATH` after installing.

## 2. Prepare XinFin client

```shell
cd ${HOME}
git clone https://github.com/XinFinOrg/XDPoSChain
cd XDPoSChain
make all
```

## 3. Create genesis

```shell
cd ${HOME}/XDPoSChain/build/bin
./puppeth
```

### 3.1 Input `XDPoS` as network name

![1678427309743](https://user-images.githubusercontent.com/7695325/224234053-c62252c0-1b1b-40fe-85d5-ea4d56341f1b.png)

```text
Please specify a network name to administer (no spaces or hyphens, please)
> XDPoS
```

### 3.2 Input `2` to configure new genesis

![1678417051286](https://user-images.githubusercontent.com/7695325/224211908-436229c9-c658-4bdb-bb1d-8c382f217c97.png)

```text
What would you like to do? (default = stats)
 1. Show network stats
 2. Configure new genesis
 3. Track new remote server
 4. Deploy network components
> 2
```

### 3.3 Input `3` to select XDPoS

![1678417349038](https://user-images.githubusercontent.com/7695325/224212620-eb8d1b76-5b67-4e5d-ad42-c582ca9c326e.png)

```text
Which consensus engine to use? (default = XDPoS)
 1. Ethash - proof-of-work
 2. Clique - proof-of-authority
 3. XDPoS - delegated-proof-of-stake
> 3
```

### 3.4 Input `2` as block time

![1678418309539](https://user-images.githubusercontent.com/7695325/224214658-7f25b327-ab78-445b-b0d6-ca8e4c52265f.png)

```text
How many seconds should blocks take? (default = 2)
> 2
```

### 3.5 Input `2000` as reward

![1678422405816](https://user-images.githubusercontent.com/7695325/224223330-16ac0cb3-5997-4b73-a836-1b7d91048194.png)

```text
How many Ethers should be rewarded to masternode? (default = 10)
> 2000
```

### 3.6 Input an address for first masternode

![1678419469021](https://user-images.githubusercontent.com/7695325/224217262-f79f26a2-9404-4b32-90c1-807a580a8879.png)

```text
Who own the first masternodes? (mandatory)
> xdc85f33E1242d87a875301312BD4EbaEe8876517BA
```

Here I input my address: `85f33E1242d87a875301312BD4EbaEe8876517BA` without `xdc` prefix.

### 3.7 Input three addresses for signers

![1678420337915](https://user-images.githubusercontent.com/7695325/224219125-3ee32475-a5b4-4be6-8c1a-c6fed98141b6.png)

```text
Which accounts are allowed to seal (signers)? (mandatory at least one)
> xdc77Cb85AE0aE070DfC013BA1a5b3EE1CED4A059a7
> xdc96509A56F0243b10a2706391b95af449712da699
> xdc2526fdEBAE27162e45da84e5E2F00AbaA1a1cc8C
> xdc
```

Here I input 3 addresses:

- 77Cb85AE0aE070DfC013BA1a5b3EE1CED4A059a7
- 96509A56F0243b10a2706391b95af449712da699
- 2526fdEBAE27162e45da84e5E2F00AbaA1a1cc8C

without `xdc` prefix.

### 3.8 Input `900` as blocks per epoch

![1678421304308](https://user-images.githubusercontent.com/7695325/224221043-be7baab9-6be5-43fc-b87f-ef6f455dc709.png)

```text
How many blocks per epoch? (default = 900)
> 900
```

### 3.9 Input `5` as gap

![1678422570325](https://user-images.githubusercontent.com/7695325/224223681-6712ca37-ded5-49bb-88d8-d71cc0372443.png)

```text
How many blocks before checkpoint need to prepare new set of masternodes? (default = 450)
> 5
```

### 3.10 Input foundation address

![1678422746528](https://user-images.githubusercontent.com/7695325/224224073-1585c991-96a3-448c-bb28-828652c5659b.png)

```text
What is foundation wallet address? (default = xdc0000000000000000000000000000000000000068)
> xdc4969aFf4Cb9993534b7E8dC088a81B6a3C63B3Cd
```

Here I input my address: `4969aFf4Cb9993534b7E8dC088a81B6a3C63B3Cd` without `xdc` prefix.

### 3.11 Input three addresses for foudation MultiSignWallet

![1678423021572](https://user-images.githubusercontent.com/7695325/224224824-0d1bc001-a78a-4df2-847e-a1d35e1ed163.png)

```text
Which accounts are allowed to confirm in Foudation MultiSignWallet?
> xdc1B1465f33C43D0c91295d0E0Ed7c406aB48a3dBa
> xdc7F39FCD52d18BAeDf705ea7D16ab5e3889Da468e
> xdc1209Bd249F097C39801e0dd81730D48584Ff33C3
> xdc
```

Here I input 3 addresses:

- 1B1465f33C43D0c91295d0E0Ed7c406aB48a3dBa
- 7F39FCD52d18BAeDf705ea7D16ab5e3889Da468e
- 1209Bd249F097C39801e0dd81730D48584Ff33C3

without `xdc` prefix.

### 3.12 Input `2` as require number

![1678423230672](https://user-images.githubusercontent.com/7695325/224225059-d4a1ec7d-8875-4bf2-b356-8140316a88ea.png)

```text
How many require for confirm tx in Foudation MultiSignWallet? (default = 2)
> 2
```

### 3.13 Input addresses for Team MultiSignWallet

![1678423446136](https://user-images.githubusercontent.com/7695325/224225469-49019198-42f3-4409-a24d-78d2bef670f6.png)

```text
Which accounts are allowed to confirm in Team MultiSignWallet?
> xdc1B1465f33C43D0c91295d0E0Ed7c406aB48a3dBa
> xdc7F39FCD52d18BAeDf705ea7D16ab5e3889Da468e
> xdc1209Bd249F097C39801e0dd81730D48584Ff33C3
> xdc
```

Here I input 3 addresses:

- 1B1465f33C43D0c91295d0E0Ed7c406aB48a3dBa
- 7F39FCD52d18BAeDf705ea7D16ab5e3889Da468e
- 1209Bd249F097C39801e0dd81730D48584Ff33C3

without `xdc` prefix.

### 3.14 Input `2` as require number

![1678423525255](https://user-images.githubusercontent.com/7695325/224225653-7a29d025-1b1b-46bf-9605-62e10059b727.png)

```text
How many require for confirm tx in Team MultiSignWallet? (default = 2)
> 2
```

### 3.15 Input address for swap wallet

![1678423730436](https://user-images.githubusercontent.com/7695325/224226074-a4c3f3b9-eb5f-4efe-a6b3-ffbed104ba47.png)

```text
What is swap wallet address for fund 55m XDC?
> xdcd43AB67DA3c972402d58521F7dc86e1355d7c3d5
```

Here I input my address: `d43AB67DA3c972402d58521F7dc86e1355d7c3d5` without `xdc` prefix.

### 3.16 Input some addresses to prefund

![1678424059975](https://user-images.githubusercontent.com/7695325/224226734-2cbc20a3-6580-4683-a6bc-6f65c23f0843.png)

```text
Which accounts should be pre-funded? (advisable at least one)
> xdcD4CE02705041F04135f1949Bc835c1Fe0885513c
> xdc85f33E1242d87a875301312BD4EbaEe8876517BA
> xdc77Cb85AE0aE070DfC013BA1a5b3EE1CED4A059a7
> xdc96509A56F0243b10a2706391b95af449712da699
> xdc2526fdEBAE27162e45da84e5E2F00AbaA1a1cc8C
> xdc4969aFf4Cb9993534b7E8dC088a81B6a3C63B3Cd
> xdc1B1465f33C43D0c91295d0E0Ed7c406aB48a3dBa
> xdc7F39FCD52d18BAeDf705ea7D16ab5e3889Da468e
> xdc1209Bd249F097C39801e0dd81730D48584Ff33C3
> xdc
```

Here I input some addresses:

- D4CE02705041F04135f1949Bc835c1Fe0885513c
- 85f33E1242d87a875301312BD4EbaEe8876517BA
- 77Cb85AE0aE070DfC013BA1a5b3EE1CED4A059a7
- 96509A56F0243b10a2706391b95af449712da699
- 2526fdEBAE27162e45da84e5E2F00AbaA1a1cc8C
- 4969aFf4Cb9993534b7E8dC088a81B6a3C63B3Cd
- 1B1465f33C43D0c91295d0E0Ed7c406aB48a3dBa
- 7F39FCD52d18BAeDf705ea7D16ab5e3889Da468e
- 1209Bd249F097C39801e0dd81730D48584Ff33C3

without `xdc` prefix.

### 3.17 Input network ID

![1678424204234](https://user-images.githubusercontent.com/7695325/224227141-4050162c-e407-4a7f-9bd8-508a5444b14b.png)

```text
Specify your chain/network ID if you want an explicit one (default = random)
> 888
```

Here I input `888`.

### 3.18 Export the genesis file

![1678424359028](https://user-images.githubusercontent.com/7695325/224227488-3b8c98c8-98ee-4b21-943b-2b9133d59991.png)

```text
What would you like to do? (default = stats)
 1. Show network stats
 2. Manage existing genesis
 3. Track new remote server
 4. Deploy network components
> 2

 1. Modify existing fork rules
 2. Export genesis configuration
 3. Remove genesis configuration
> 2

Which file to save the genesis into? (default = XDPoS.json)
> XDPoS.json
```

- Select `2` to manage existing genesis.
- Select `2` to export genesis configuration
- Enter genesis filename: `XDPOS.json`
- Press CtrL + C to exit

The gensis file is saved to: `${HOME}/XDPoSChain/build/bin/XDPoS.json`.

### 3.19 Modify the genesis file

Edit the genesis file `${HOME}/XDPoSChain/build/bin/XDPoS.json`, add the below line:

```text
"constantinopleBlock": 4,
```

under the line `"eip155Block": 3,` according to [issue 196](https://github.com/XinFinOrg/XDPoSChain/issues/196).

## 4. Setup bootnode

```shell
cd ${HOME}/XDPoSChain/build/bin
./bootnode -genkey bootnode.key
./bootnode -nodekey ./bootnode.key
```

![1678428141480](https://user-images.githubusercontent.com/7695325/224236113-ddd1670b-9300-4f5b-8d68-01da199e9831.png)

Copy bootnode information in above shown:

```text
enode://62457be5ca9c9ba3913d1513c22ca963b94548a7db06e7a629fec5b654ab7b09a704cba22229107b3f54848ae58e845dcce98393b48be619cc2860d56dd57198
```

Then press Ctrl+C to stop bootnode program.

## 5. Start the masternodes

### 5.1 Download Local_DPoS_Setup

```shell
cd ${HOME}
git clone https://github.com/gzliudan/Local_DPoS_Setup
cd Local_DPoS_Setup
git checkout private-network
```

### 5.2 Copy genesis and bootkey files

```shell
cp ${HOME}/XDPoSChain/build/bin/XDPoS.json ${HOME}/Local_DPoS_Setup/genesis/XDPoS-3-signers.json
cp ${HOME}/XDPoSChain/build/bin/bootnode.key ${HOME}/Local_DPoS_Setup
```

### 5.3 Setup ENODE and private keys

Edit file `${HOME}/Local_DPoS_Setup/.env`, add 4 private keys without 0x prefix:

```text
ENODE=<ENODE_VALUE>
PRIVATE_KEY_0=<KEY_0>
PRIVATE_KEY_1=<KEY_1>
PRIVATE_KEY_2=<KEY_2>
PRIVATE_KEY_3=<KEY_3>
```

- ENODE_VALUE is from step 4 with below format: `enode://62457be5ca9c9ba3913d1513c22ca963b94548a7db06e7a629fec5b654ab7b09a704cba22229107b3f54848ae58e845dcce98393b48be619cc2860d56dd57198@127.0.0.1:30301`
- KEY_0 is the private key for first masternode in section 3.6
- KEY_1, KEY_2, KEY_3 are private keys for three signers in section 3.7

### 5.4 Start private networks

```shell
cd ${HOME}/Local_DPoS_Setup
./start-3-signers-networks.sh
```
