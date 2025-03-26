# Blockchain Implementation Documentation

## Overview

The blockchain implementation provides a distributed ledger system that maintains a consistent state across multiple participants. It supports key-value storage, participant management, and secure state transitions. The blockchain is designed with security in mind, ensuring only valid blocks with proper signatures and correct heights can be applied.

## Core Components

### Block Structure

As defined in the e2e_api.tl scheme:

```
e2e.chain.block signature:int512 flags:# prev_block_hash:int256 changes:vector<e2e.chain.Change> height:int state_proof:e2e.chain.StateProof signature_public_key:flags.0?int256 = e2e.chain.Block;
```

A block consists of:
- **Signature**: Cryptographic signature verifying the block's authenticity
- **Previous Block Hash**: Links to the previous block, creating a chain
- **Changes**: A vector of operations to apply to the blockchain state
- **Height**: Sequential block number, critical for validation
- **State Proof**: Contains hashes and states for validation. This is proof of the state of the blockchain after the block was applied.
- **Signature Public Key**: The key of the participant who created the block

### Change Types

The blockchain supports three types of changes:

1. **ChangeSetValue**: Updates a key-value pair in the blockchain
   ```
   e2e.chain.changeSetValue key:bytes value:bytes = e2e.chain.Change;
   ```

2. **ChangeSetGroupState**: Updates the group of participants and their permissions
   ```
   e2e.chain.groupParticipant user_id:long public_key:int256 flags:# add_users:flags.0?true remove_users:flags.1?true = e2e.chain.GroupParticipant;
   e2e.chain.groupState participants:vector<e2e.chain.GroupParticipant> = e2e.chain.GroupState;
   e2e.chain.changeSetGroupState group_state:e2e.chain.GroupState = e2e.chain.Change;
   ```

3. **ChangeSetSharedKey**: Updates encryption keys shared among participants
   ```
   e2e.chain.sharedKey ek:int256 encrypted_shared_key:string dest_user_id:vector<long> dest_header:vector<bytes> = e2e.chain.SharedKey;
   e2e.chain.changeSetSharedKey shared_key:e2e.chain.SharedKey = e2e.chain.Change;
   ```

### Participants and Permissions

Participants in the blockchain have specific permissions:
- **AddUsers**: Can add new participants to the blockchain
- **RemoveUsers**: Can remove existing participants from the blockchain

```
e2e.chain.groupParticipant user_id:long public_key:int256 flags:# add_users:flags.0?true remove_users:flags.1?true = e2e.chain.GroupParticipant;
```

### Implementation Details

#### Key-Value State

The blockchain uses a persistent trie for key-value storage, with the following properties:
- Supports set/get operations
- Generates pruned trees for a given set of keys
- A pruned tree allows:
  - `get` operations for any of the specified keys
  - `set` operations for any of those keys to create a new (pruned) trie

```c++
td::Result<TrieRef> set(TrieRef n, BitString key, td::Slice value, td::Slice snapshot = {});
td::Result<std::string> get(const TrieRef &n, BitString key, td::Slice snapshot = {});
td::Result<TrieRef> generate_pruned_tree(const TrieRef &n, td::Span<td::Slice> keys, td::Slice snapshot = {});
```

The trie can be serialized for network transmission or persistent storage:

```c++
static td::Result<std::string> serialize_for_network(TrieRef node);
static td::Result<TrieRef> fetch_from_network(td::Slice data);
static td::Result<std::string> serialize_for_snapshot(TrieRef node, td::Slice snapshot);
static td::Result<TrieRef> fetch_from_snapshot(td::Slice snapshot);
```

- `{serialize_for,fetch_from}_network` is used for passing pruned trie over network
- `{serialize_for,fetch_from}_snapshot` is used by the server to persist the whole state to disk

#### Blockchain State

The complete blockchain state consists of:
- Trie (TrieRef root + Slice snapshot) - key-value storage
- Group State (participants and their permissions) - participants and their permissions
- Shared Key information - encryption keys shared among participants

## Expected Behaviors

### Block Application Process

**Block is either applied completely or not at all.**

1. Block height is checked. It must be exactly one more than the current blockchain height.
   - If the height is incorrect, the block is rejected with `HEIGHT_MISMATCH`
2. Hash of the previous block is checked. It must be equal to the hash of the last applied block.
   - If the hash is incorrect, the block is rejected with `PREVIOUS_BLOCK_HASH_MISMATCH`
3. Would identify permissions of the participant who created the block, i.e. the one with `signer_public_key` public key.
   - If the participant is not in the group state, the block is rejected with `PARTICIPANT_NOT_FOUND`
   - Otherwise, permissions are defined by the group state before application of the block.
4. We should check that the block signature is valid.
   - If the signature is invalid, the block is rejected with `INVALID_SIGNATURE`
5. After that we apply changes from the block ONE BY ONE.
   - Before applying a change, we should check that the participant has enough permissions to apply the change.
   - Then, we apply the change.
   - ! After applying a block, permissions of block's creator could be changed. It is important becase the following changes should be applied with new permissions. The idea is that applications of changes in the same block should lead to the same state as applications of changes in different blocks.
   - If the change is not valid, the block is rejected with the corresponding error.
6. After all changes are applied, we check state proof in the block. Is must be valid for the new state.
   - If the state proof is invalid, the block is rejected with `INVALID_STATE_PROOF`

To apply the first block an ephemeral -1 block is used
   - It has hash UInt256(0)
   - It has height -1
   - It has only one participant - Participant(user_id = 0, public_key = signer_public_key, permissions = all)

Also, there are several optimization of block serialization:
   - signer_public_key could be omitted if it is the same as the public key of ther first participant in the group state
   - `group_state` in `state_proof` could be omitted if ther is `SetGroupState` change in the block
   - `shared_key` in `state_proof` could be omitted if there is `SetSharedKey` or `SetGroupState` change in the block.

### Applying Changes

The idea is that applications of changes in the same block should lead to the same state as applications of changes in different blocks.

#### Key Value Updates

Currently, all participants can update any key with a new value. Change is always successful. Deletions are the same as overwriting with an empty value.

- Trie is updated with new value
- Trie hash must be stored in the new state proof

### Participant Management

- Only participants with `AddUsers` permission can add new participants
- Participant may add users with permissions which are subset (nonstrict) of its own permissions.
- Only participants with `RemoveUsers` permission can remove existing participants
- It is OK to remove yourself from the group. In this case you will not be able to add yourself back.
- Public key and user_id are unique in group state.
- Any new state of the group is allowed otherwise.
- shared_key is automatically cleared by this change.

#### Shared Key Updates

- Shared key can't be overwritten by other participants. One has to update group state to clear the key first
- shared_key is automatically cleared by `SetGroupState` change.
- shared_key must contain all user_ids of all participants and only them.
- how shared_key is encrypted is not blockchains concern


## Known Behaviors and Considerations

### Multiple Blocks at Same Height

If two blocks are built concurrently targeting the same height:
- Only the first applied block will succeed
- The second block will be rejected with `HEIGHT_MISMATCH`
- This is correct security behavior, not a bug

### Outdated Proofs Handling

Client library do not store the whole key value state. So to create a block client should receive a proof of all changed keys from the server.

