#!/bin/sh

# -----------------------------------------------------------------------
#  Copyright (c) 2010-2013, Plausible Labs Cooperative, Inc.
#
#  Author: Landon Fuller <landonf@plausible.coop>
#
#  Permission is hereby granted, free of charge, to any person obtaining
#  a copy of this software and associated documentation files (the
#  ``Software''), to deal in the Software without restriction, including
#  without limitation the rights to use, copy, modify, merge, publish,
#  distribute, sublicense, and/or sell copies of the Software, and to
#  permit persons to whom the Software is furnished to do so, subject to
#  the following conditions:
#
#  The above copyright notice and this permission notice shall be included
#  in all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED ``AS IS'', WITHOUT WARRANTY OF ANY KIND,
#  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#  NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
#  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
#  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
#  DEALINGS IN THE SOFTWARE.
#  -----------------------------------------------------------------------

process() {
	local file=$1
	local opts=`echo $2`
	local count=$3

	eval cc -o regression-bins/tbin.$file.${count} ${file} ${opts}
}

main() {
	local ifs_bak=$IFS
	local ifs_nl="
"

	IFS=$ifs_nl
	local count="1"
	for opt in `grep -H "TEST-OPTIONS:" regression/*.s`; do
		IFS=$ifs_back
		local fname=`echo "${opt}" | awk -F : '{print $1}'`
		local opts=`echo "${opt}" | cut -d ' ' -f 3-`
		process "$fname" "${opts}" "${count}"
		IFS=$ifs_nl
		count=`expr $count + 1`
	done
}

main
