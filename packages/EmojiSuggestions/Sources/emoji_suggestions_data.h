/*
WARNING! All changes made in this file will be lost!
Created from 'empty' by 'codegen_emoji'

This file is part of Telegram Desktop,
the official desktop version of Telegram messaging app, see https://telegram.org

Telegram Desktop is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

It is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

In addition, as a special exception, the copyright holders give permission
to link the code of portions of this program with the OpenSSL library.

Full license: https://github.com/telegramdesktop/tdesktop/blob/master/LICENSE
Copyright (c) 2014-2017 John Preston, https://desktop.telegram.org
*/
#pragma once

#include "emoji_suggestions.h"

namespace Ui {
namespace Emoji {
namespace internal {

struct Replacement {
	utf16string emoji;
	utf16string replacement;
	std::vector<utf16string> words;
};

constexpr auto kReplacementMaxLength = 55;

void InitReplacements();
const std::vector<const Replacement*> *GetReplacements(utf16char first);
utf16string GetReplacementEmoji(utf16string replacement);

} // namespace internal
} // namespace Emoji
} // namespace Ui
