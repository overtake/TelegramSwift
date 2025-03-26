//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/e2e/Blockchain.h"

#include "td/e2e/Keys.h"

#include "td/telegram/e2e_api.hpp"

#include "td/utils/algorithm.h"
#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/format.h"
#include "td/utils/misc.h"
#include "td/utils/overloaded.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/tl_helpers.h"
#include "td/utils/tl_parsers.h"

#include <map>
#include <set>
#include <tuple>
#include <utility>

namespace tde2e_core {

GroupParticipant GroupParticipant::from_tl(const td::e2e_api::e2e_chain_groupParticipant &participant) {
  return GroupParticipant{participant.user_id_, participant.flags_, PublicKey::from_u256(participant.public_key_)};
}

e2e::object_ptr<e2e::e2e_chain_groupParticipant> GroupParticipant::to_tl() const {
  return e2e::make_object<e2e::e2e_chain_groupParticipant>(user_id, public_key.to_u256(), flags, add_users(),
                                                           remove_users());
}
td::Result<GroupParticipant> GroupState::get_participant(td::int64 user_id) const {
  for (const auto &participant : participants) {
    if (participant.user_id == user_id) {
      return participant;
    }
  }
  return td::Status::Error("Participant not found");
}

td::Result<GroupParticipant> GroupState::get_participant(const PublicKey &public_key) const {
  for (const auto &participant : participants) {
    if (participant.public_key == public_key) {
      return participant;
    }
  }
  return td::Status::Error("Participant not found");
}
GroupStateRef GroupState::from_tl(const td::e2e_api::e2e_chain_groupState &state) {
  auto participant_from_tl = [](const td::e2e_api::object_ptr<td::e2e_api::e2e_chain_groupParticipant> &participant) {
    return GroupParticipant::from_tl(*participant);
  };
  return std::make_shared<GroupState>(GroupState{td::transform(state.participants_, participant_from_tl)});
}
e2e::object_ptr<e2e::e2e_chain_groupState> GroupState::to_tl() const {
  return e2e::make_object<e2e::e2e_chain_groupState>(
      td::transform(participants, [](const GroupParticipant &participant) { return participant.to_tl(); }));
}
GroupStateRef GroupState::empty_state() {
  static GroupStateRef state = std::make_shared<GroupState>(GroupState{});
  return state;
}
GroupSharedKeyRef GroupSharedKey::from_tl(const td::e2e_api::e2e_chain_sharedKey &shared_key) {
  return std::make_shared<GroupSharedKey>(GroupSharedKey{PublicKey::from_u256(shared_key.ek_),
                                                         shared_key.encrypted_shared_key_, shared_key.dest_user_id_,
                                                         shared_key.dest_header_});
}
e2e::object_ptr<e2e::e2e_chain_sharedKey> GroupSharedKey::to_tl() const {
  return e2e::make_object<e2e::e2e_chain_sharedKey>(ek.to_u256(), encrypted_shared_key,
                                                    std::vector<td::int64>(dest_user_id), std::vector(dest_header));
}
GroupSharedKeyRef GroupSharedKey::empty_shared_key() {
  static GroupSharedKeyRef shared_key = std::make_shared<GroupSharedKey>(GroupSharedKey{});
  return shared_key;
}
ChangeSetValue ChangeSetValue::from_tl(const td::e2e_api::e2e_chain_changeSetValue &change) {
  return ChangeSetValue{change.key_, change.value_};
}
e2e::object_ptr<e2e::e2e_chain_changeSetValue> ChangeSetValue::to_tl() const {
  return e2e::make_object<e2e::e2e_chain_changeSetValue>(key, value);
}
ChangeSetGroupState ChangeSetGroupState::from_tl(const td::e2e_api::e2e_chain_changeSetGroupState &change) {
  return ChangeSetGroupState{GroupState::from_tl(*change.group_state_)};
}
e2e::object_ptr<e2e::e2e_chain_changeSetGroupState> ChangeSetGroupState::to_tl() const {
  return e2e::make_object<e2e::e2e_chain_changeSetGroupState>(group_state->to_tl());
}
ChangeSetSharedKey ChangeSetSharedKey::from_tl(const td::e2e_api::e2e_chain_changeSetSharedKey &change) {
  return ChangeSetSharedKey{GroupSharedKey::from_tl(*change.shared_key_)};
}
e2e::object_ptr<e2e::e2e_chain_changeSetSharedKey> ChangeSetSharedKey::to_tl() const {
  return e2e::make_object<e2e::e2e_chain_changeSetSharedKey>(shared_key->to_tl());
}
Change Change::from_tl(const td::e2e_api::e2e_chain_Change &change) {
  Change res;
  downcast_call(
      const_cast<td::e2e_api::e2e_chain_Change &>(change),
      td::overloaded(
          [&](td::e2e_api::e2e_chain_changeSetValue &change_t) { res.value = ChangeSetValue::from_tl(change_t); },
          [&](td::e2e_api::e2e_chain_changeSetGroupState &change_t) {
            res.value = ChangeSetGroupState::from_tl(change_t);
          },
          [&](td::e2e_api::e2e_chain_changeSetSharedKey &change_t) {
            res.value = ChangeSetSharedKey::from_tl(change_t);
          }));
  return res;
}
e2e::object_ptr<e2e::e2e_chain_Change> Change::to_tl() const {
  return std::visit(
      td::overloaded(
          [](const ChangeSetValue &change) -> td::e2e_api::object_ptr<e2e::e2e_chain_Change> { return change.to_tl(); },
          [](const ChangeSetGroupState &change) -> td::e2e_api::object_ptr<e2e::e2e_chain_Change> {
            return change.to_tl();
          },
          [](const ChangeSetSharedKey &change) -> td::e2e_api::object_ptr<e2e::e2e_chain_Change> {
            return change.to_tl();
          }),
      value);
}
td::UInt256 Block::calc_hash() const {
  if (height_ == -1) {
    return {};
  }
  auto serialized_block = serialize_boxed(*to_tl());
  td::UInt256 hash;
  td::sha256(serialized_block, hash.as_mutable_slice());
  return hash;
}
Block Block::from_tl(const e2e::e2e_chain_block &block) {
  Block result;
  result.state_proof_ = StateProof::from_tl(*block.state_proof_);
  if (block.flags_ & 1) {
    result.o_signature_public_key_ = PublicKey::from_u256(block.signature_public_key_);
  }
  result.signature_ = Signature::from_u512(block.signature_);
  result.prev_block_hash_ = block.prev_block_hash_;
  auto change_from_tl = [&](auto &obj) {
    return Change::from_tl(*obj);
  };
  result.changes_ = td::transform(block.changes_, change_from_tl);
  result.height_ = block.height_;
  return result;
}

td::Result<Block> Block::from_tl_serialized(td::Slice new_block) {
  td::TlParser parser(new_block);
  auto magic = parser.fetch_int();
  if (magic != td::e2e_api::e2e_chain_block::ID) {
    return td::Status::Error(PSLICE() << "Expected magic " << td::format::as_hex(td::e2e_api::e2e_chain_block::ID)
                                      << td::format::as_hex(magic));
  }
  auto block_tl = td::e2e_api::e2e_chain_block::fetch(parser);
  parser.fetch_end();
  TRY_STATUS(parser.get_status());
  return from_tl(*block_tl);
}

e2e::object_ptr<e2e::e2e_chain_block> Block::to_tl() const {
  td::int32 flags{};
  auto state_proof = state_proof_.to_tl();
  td::UInt256 public_key{};
  if (o_signature_public_key_) {
    public_key = o_signature_public_key_.value().to_u256();
    flags |= e2e::e2e_chain_block::SIGNATURE_PUBLIC_KEY_MASK;
  }
  auto changes = td::transform(changes_, [](const auto &change) { return change.to_tl(); });

  return e2e::make_object<e2e::e2e_chain_block>(signature_.to_u512(), flags, prev_block_hash_, std::move(changes),
                                                height_, std::move(state_proof), public_key);
}
std::string Block::to_tl_serialized() const {
  return serialize_boxed(*to_tl());
}
td::StringBuilder &operator<<(td::StringBuilder &sb, const Block &block) {
  return sb << "Block(sign=" << block.signature_
            << "..., prev_hash=" << hex_encode(block.prev_block_hash_.as_slice().substr(0, 8))
            << " height=" << block.height_ << " \n"
            << block.state_proof_ << "\n"
            << block.changes_ << "\n"
            << block.o_signature_public_key_ << ")";
}
td::Result<std::string> KeyValueState::get_value(td::Slice key) const {
  return get(node_, BitString(key), snapshot_.value());
}
td::Result<std::string> KeyValueState::gen_proof(td::Span<td::Slice> keys) const {
  TRY_RESULT(pruned_tree, generate_pruned_tree(node_, keys, snapshot_.value()));
  return TrieNode::serialize_for_network(pruned_tree);
}
td::Result<KeyValueState> KeyValueState::create_from_hash(KeyValueHash hash) {
  auto node = std::make_shared<TrieNode>(hash.hash);
  return KeyValueState{std::move(node), td::Slice()};
}
td::Result<KeyValueState> KeyValueState::create_from_snapshot(td::Slice snapshot) {
  TRY_RESULT(node, TrieNode::fetch_from_snapshot(snapshot));
  return KeyValueState{std::move(node), snapshot};
}
td::Result<std::string> KeyValueState::build_snapshot() const {
  return TrieNode::serialize_for_snapshot(node_, snapshot_.value());
}

td::Status KeyValueState::set_value(td::Slice key, td::Slice value) {
  TRY_RESULT_ASSIGN(node_, set(node_, BitString(key), value, snapshot_.value()));
  return td::Status::OK();
}

td::UInt256 KeyValueState::get_hash() const {
  //TODO: hash of public key
  return node_->hash;
}

StateProof StateProof::from_tl(const td::e2e_api::e2e_chain_stateProof &proof) {
  StateProof res;
  res.kv_hash = KeyValueHash{proof.kv_hash_};
  if (proof.group_state_) {
    res.o_group_state = GroupState::from_tl(*proof.group_state_);
  }
  if (proof.shared_key_) {
    res.o_shared_key = GroupSharedKey::from_tl(*proof.shared_key_);
  }
  return res;
}
e2e::object_ptr<e2e::e2e_chain_stateProof> StateProof::to_tl() const {
  td::int32 flags{};
  e2e::object_ptr<e2e::e2e_chain_groupState> o_group_state_tl;
  if (o_group_state) {
    o_group_state_tl = o_group_state.value()->to_tl();
    flags |= td::e2e_api::e2e_chain_stateProof::GROUP_STATE_MASK;
  }
  e2e::object_ptr<e2e::e2e_chain_sharedKey> o_shared_key_tl;
  if (o_shared_key) {
    o_shared_key_tl = o_shared_key.value()->to_tl();
    flags |= td::e2e_api::e2e_chain_stateProof::SHARED_KEY_MASK;
  }

  return e2e::make_object<e2e::e2e_chain_stateProof>(flags, kv_hash.hash, std::move(o_group_state_tl),
                                                     std::move(o_shared_key_tl));
}
td::StringBuilder &operator<<(td::StringBuilder &sb, const StateProof &state) {
  sb << "StateProof{";
  sb << "\n\tkv=" << td::format::as_hex_dump<0>(state.kv_hash.hash.as_slice().substr(0, 8));
  if (state.o_group_state) {
    sb << "\n\tgroup=" << **state.o_group_state;
  }
  if (state.o_shared_key) {
    sb << "\n\tgroup=" << **state.o_shared_key;
  }
  return sb << "}";
}

State State::create_empty() {
  return State{KeyValueState{}, GroupState::empty_state(), GroupSharedKey::empty_shared_key()};
}

td::Status State::set_value(td::Slice key, td::Slice value) {
  return key_value_state_.set_value(key, value);
}

td::Status State::set_value_fast(KeyValueHash key_value_hash) {
  TRY_RESULT_ASSIGN(key_value_state_, KeyValueState::create_from_hash(key_value_hash));
  return td::Status::OK();
}

td::Status State::set_group_state(GroupStateRef group_state, const GroupParticipant &participant) {
  std::map<td::int64, td::int32> old_participants;
  std::set<td::int64> new_participants;
  std::set<PublicKey> new_keys;
  for (const auto &p : group_state_->participants) {
    old_participants[p.user_id] = p.flags;
  }
  for (const auto &p : group_state->participants) {
    new_participants.insert(p.user_id);
    new_keys.insert(p.public_key);
  }
  if (new_participants.size() != group_state->participants.size()) {
    return Error(E::InvalidBlock_InvalidGroupState, "duplicate user_id");
  }
  if (new_keys.size() != group_state->participants.size()) {
    return Error(E::InvalidBlock_InvalidGroupState, "duplicate public_key");
  }

  td::int32 needed_flags = 0;
  td::int32 new_flags = 0;
  for (const auto &p : group_state_->participants) {
    if (!new_participants.count(p.user_id)) {
      needed_flags |= GroupParticipantFlags::RemoveUsers;
    }
  }
  for (const auto &p : group_state->participants) {
    auto old_p = old_participants.find(p.user_id);
    if (old_p == old_participants.end()) {
      needed_flags |= GroupParticipantFlags::AddUsers | p.flags;
    } else {
      new_flags |= p.flags & ~old_p->second;
    }
  }

  td::int32 missing_flags = needed_flags & ~participant.flags;
  if (missing_flags & GroupParticipantFlags::AddUsers) {
    return Error(E::InvalidBlock_NoPermissions, "Missing add_users flag");
  }
  if (missing_flags & GroupParticipantFlags::RemoveUsers) {
    return Error(E::InvalidBlock_NoPermissions, "Missing remove_users flag");
  }
  td::int32 missing_new_flags = new_flags & ~participant.flags;
  if (missing_new_flags) {
    return Error(E::InvalidBlock_NoPermissions, "Can't create user with more flags than yourself");
  }

  group_state_ = std::move(group_state);
  return td::Status::OK();
}

td::Status State::clear_shared_key() {
  shared_key_ = GroupSharedKey::empty_shared_key();
  return td::Status::OK();
}
td::Status State::set_shared_key(GroupSharedKeyRef shared_key) {
  if (*shared_key_ != *GroupSharedKey::empty_shared_key()) {
    return td::Status::Error("Shared key is already set");
  }
  shared_key_ = std::move(shared_key);
  std::set<td::int64> participants;
  for (const auto &p : group_state_->participants) {
    participants.insert(p.user_id);
  }
  for (auto dest_user_id : shared_key_->dest_user_id) {
    if (!participants.count(dest_user_id)) {
      return td::Status::Error("Unknown user_id in SetSharedKey");
    }
  }
  return td::Status::OK();
}

td::Status State::validate_state(const StateProof &state_proof) const {
  if (state_proof.kv_hash.hash != key_value_state_.get_hash()) {
    return td::Status::Error("State hash mismatch");
  }

  if (has_group_state_change_ && state_proof.o_group_state) {
    return Error(E::InvalidBlock_InvalidStateProof_Group,
                 "Group state must be omitted when there is a group state change");
  }
  if (!has_group_state_change_ && !state_proof.o_group_state) {
    return Error(E::InvalidBlock_InvalidStateProof_Group,
                 "Group state must be provided when there is no group state change");
  }
  if (!has_group_state_change_ && **state_proof.o_group_state != *group_state_) {
    return Error(E::InvalidBlock_InvalidStateProof_Group, "group state differs");
  }

  bool shared_key_must_be_omitted = has_group_state_change_ || has_shared_key_change_;
  if (shared_key_must_be_omitted && state_proof.o_shared_key) {
    return Error(E::InvalidBlock_InvalidStateProof_Secret, "Shared key state must be omitted");
  }
  if (!shared_key_must_be_omitted && !state_proof.o_shared_key) {
    return Error(E::InvalidBlock_InvalidStateProof_Secret, "Shared key state must be provided");
  }
  if (!shared_key_must_be_omitted && **state_proof.o_shared_key != *shared_key_) {
    return Error(E::InvalidBlock_InvalidStateProof_Secret, "shared key state differs");
  }

  return td::Status::OK();
}

td::Status State::apply_change(const Change &change_outer, const GroupParticipant &participant, bool full_apply) {
  return std::visit(td::overloaded(
                        [this, full_apply](const ChangeSetValue &change) {
                          if (full_apply) {
                            return set_value(change.key, change.value);
                          }
                          return td::Status::OK();
                        },
                        [this, &participant](const ChangeSetGroupState &change) {
                          has_group_state_change_ = true;
                          TRY_STATUS(set_group_state(change.group_state, participant));
                          return clear_shared_key();
                        },
                        [this](const ChangeSetSharedKey &change) {
                          has_shared_key_change_ = true;
                          return set_shared_key(change.shared_key);
                        }),
                    change_outer.value);
}

td::Status State::apply(Block &block, bool validate_state_hash) {
  // To apply the first block an ephemeral -1 block is used
  //   - It has only one participant - Participant(user_id = 0, public_key = signer_public_key, permissions = all)
  if (block.height_ == 0) {
    CHECK(group_state_->empty());
    if (block.o_signature_public_key_) {
      group_state_ = std::make_shared<GroupState>(
          GroupState{{GroupParticipant{0, GroupParticipantFlags::AddUsers | GroupParticipantFlags::RemoveUsers,
                                       block.o_signature_public_key_.value()}}});
    }
  }

  // 4. Would identify permissions of the participant who created the block, i.e. the one with `signer_public_key` public key.
  //   - If the participant is not in the group state, the block is rejected with `PARTICIPANT_NOT_FOUND`
  //   - Otherwise, permissions are defined by the group state before application of the block.
  GroupParticipant participant;
  if (block.o_signature_public_key_) {
    TRY_RESULT_ASSIGN(participant, group_state_->get_participant(block.o_signature_public_key_.value()));
  } else {
    if (group_state_->empty()) {
      return td::Status::Error("Participant not found");
    }
    participant = group_state_->participants[0];
  }

  // 5. Verifies the signature of the block.
  TRY_STATUS(block.verify_signature(participant.public_key));

  // 6. Applies the changes to the state.
  //   - If `validate_state_hash` is true, the state hash is validated.
  //   - Otherwise, the state hash is set to the hash of the block.
  has_shared_key_change_ = false;
  has_group_state_change_ = false;
  for (auto &change : block.changes_) {
    TRY_STATUS(apply_change(change, participant, validate_state_hash));
  }
  if (!validate_state_hash) {
    TRY_STATUS(set_value_fast(block.state_proof_.kv_hash));
  }

  TRY_STATUS(validate_state(block.state_proof_));

  return td::Status::OK();
}

td::Result<State> State::create_from_block(const Block &block, td::optional<td::Slice> o_snapshot) {
  KeyValueState key_value_state;
  GroupStateRef group_state;
  GroupSharedKeyRef shared_key;

  if (o_snapshot) {
    TRY_RESULT_ASSIGN(key_value_state, KeyValueState::create_from_snapshot(o_snapshot.value()));
  } else {
    TRY_RESULT_ASSIGN(key_value_state, KeyValueState::create_from_hash(block.state_proof_.kv_hash));
  }

  // For the first block we fixup group state. So the first signer
  if (block.o_signature_public_key_ && block.height_ == 0) {
    group_state = std::make_shared<GroupState>(
        GroupState{{GroupParticipant{0, GroupParticipantFlags::AddUsers | GroupParticipantFlags::RemoveUsers,
                                     block.o_signature_public_key_.value()}}});
  }

  for (const auto &change_v : block.changes_) {
    std::visit(td::overloaded([](const ChangeSetValue &change) {},
                              [&](const ChangeSetGroupState &change) {
                                group_state = change.group_state;
                                shared_key = GroupSharedKey::empty_shared_key();
                              },
                              [&](const ChangeSetSharedKey &change) { shared_key = change.shared_key; }),
               change_v.value);
  }

  if (block.state_proof_.o_group_state) {
    group_state = block.state_proof_.o_group_state.value();
  }
  if (block.state_proof_.o_shared_key) {
    shared_key = block.state_proof_.o_shared_key.value();
  }
  if (!group_state) {
    return Error(E::InvalidBlock_InvalidStateProof_Group, "no group state proof");
  }
  if (!shared_key) {
    return Error(E::InvalidBlock_InvalidStateProof_Secret, "no shared key");
  }
  return State(key_value_state, group_state, shared_key);
}

td::Result<Block> Blockchain::build_block(std::vector<Change> changes, const PrivateKey &private_key) const {
  //TODO(now): check if we are allowed to sign this block
  auto public_key = private_key.to_public_key();
  auto state = state_;
  td::int32 height = last_block_.height_ + 1;
  if (height == 0) {
    state.group_state_ = std::make_shared<GroupState>(GroupState{
        {GroupParticipant{0, GroupParticipantFlags::AddUsers | GroupParticipantFlags::RemoveUsers, public_key}}});
  }
  TRY_RESULT(participant, state.group_state_->get_participant(public_key));

  for (const auto &change : changes) {
    TRY_STATUS(state.apply_change(change, participant, true));
  }

  StateProof state_proof;
  state_proof.kv_hash = KeyValueHash{state.key_value_state_.get_hash()};
  state_proof.o_group_state = state.group_state_;
  state_proof.o_shared_key = state.shared_key_;
  for (const auto &change_v : changes) {
    std::visit(td::overloaded([](const ChangeSetValue &change) {},
                              [&](const ChangeSetGroupState &change) {
                                state_proof.o_group_state = {};
                                state_proof.o_shared_key = {};
                              },
                              [&](const ChangeSetSharedKey &change) { state_proof.o_shared_key = {}; }),
               change_v.value);
  }

  Block block;
  block.height_ = height;
  block.prev_block_hash_ = last_block_hash_;
  block.changes_ = std::move(changes);
  block.o_signature_public_key_ = public_key;
  block.state_proof_ = std::move(state_proof);
  TRY_STATUS(block.sign_inplace(private_key));
  return block;
}

td::Status Blockchain::try_apply_block(Block block, bool validate_state_hash) {
  // To apply the first block an ephemeral -1 block is used
  //   - It has hash UInt256(0)
  //   - It has height -1
  //   - It has only one participant - Participant(user_id = 0, public_key = signer_public_key, permissions = all)

  if (block.height_ != get_height() + 1) {
    return Error(E::InvalidBlock_HeightMismatch,
                 PSLICE() << "new_block.height=" << block.height_ << " != 1 + last_block.height=" << get_height());
  }

  if (block.prev_block_hash_ != last_block_hash_) {
    return Error(E::InvalidBlock_HashMismatch);
  }

  // TODO: validate total size of block
  auto state = state_;
  // TODO: use hint (state from build_block)
  TRY_STATUS(state.apply(block, validate_state_hash));

  TRY_STATUS(state.validate_state(block.state_proof_));

  // NO errors after this point
  state_ = std::move(state);

  last_block_hash_ = block.calc_hash();

  last_block_ = std::move(block);
  return td::Status::OK();
}

Block Blockchain::set_value(td::Slice key, td::Slice value, const PrivateKey &private_key) const {
  return build_block({Change{ChangeSetValue{key.str(), value.str()}}}, private_key).move_as_ok();
}

td::int64 Blockchain::get_height() const {
  return last_block_.height_;
}

td::UInt256 as_key(td::Slice key) {
  CHECK(key.size() == 32);
  td::UInt256 key_int256;
  key_int256.as_mutable_slice().copy_from(key);
  return key_int256;
}

td::Result<Blockchain> Blockchain::create_from_block(Block block, td::optional<td::Slice> o_snapshot) {
  Blockchain res;
  res.last_block_hash_ = block.calc_hash();
  TRY_RESULT_ASSIGN(res.state_, State::create_from_block(block, std::move(o_snapshot)));
  res.last_block_ = std::move(block);

  return res;
}

td::Result<ClientBlockchain> ClientBlockchain::create_from_block(td::Slice block_slice, const PublicKey &public_key) {
  TRY_RESULT(block, Block::from_tl_serialized(block_slice));
  TRY_RESULT(blockchain, Blockchain::create_from_block(std::move(block)));
  // TODO: check public key is in blockchain
  ClientBlockchain res;
  res.blockchain_ = std::move(blockchain);
  return res;
}

td::Result<ClientBlockchain> ClientBlockchain::create_empty() {
  ClientBlockchain res;
  res.blockchain_ = Blockchain::create_empty();
  return res;
}

td::Result<std::vector<Change>> ClientBlockchain::try_apply_block(td::Slice block_slice) {
  TRY_RESULT(block, Block::from_tl_serialized(block_slice));

  TRY_STATUS(blockchain_.try_apply_block(block, false));
  for (auto &change : block.changes_) {
    if (std::holds_alternative<ChangeSetValue>(change.value)) {
      auto &change_value = std::get<ChangeSetValue>(change.value);
      map_[as_key(change_value.key)] = Entry{block.height_, change_value.value};
    }
  }

  return std::move(block.changes_);
}

td::Status ClientBlockchain::add_proof(td::Slice proof) {
  TRY_RESULT(state, TrieNode::fetch_from_network(proof));

  if (state->hash != blockchain_.state_.key_value_state_.get_hash()) {
    return td::Status::Error("Invalid proof");
  }
  // TODO: merge proof
  blockchain_.state_.key_value_state_.node_ = state;
  return td::Status::OK();
}

td::Result<std::string> ClientBlockchain::build_block(const std::vector<Change> &changes,
                                                      const PrivateKey &private_key) const {
  TRY_RESULT(block, blockchain_.build_block(changes, private_key));
  //return serialize(*block.to_tl());
  return block.to_tl_serialized();;
}

td::Result<std::string> ClientBlockchain::get_value(td::Slice key) const {
  auto it = map_.find(as_key(key));
  if (it != map_.end()) {
    return it->second.value;
  }
  return blockchain_.state_.key_value_state_.get_value(key);
}

}  // namespace tde2e_core
