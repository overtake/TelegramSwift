## SBC XQ

SBC XQ is standard SBC codec operating at high bitrates and thus reaching the
transparent audio transport quality of AptX (HD) or other proprietary codecs.

A2DP specification (A2DP SPEC) defines SBC parameters. These parameters are
negotiated between the source (SRC) and the receiver (SNK) at connection time :

- Audio channel mode : Joint Stereo, Stereo, Dual Channel, Mono : all modes
  are MANDATORY for the SNK according to A2DP specification
- Number of subbands: 4 or 8 - both MANDATORY for the SNK implementation
- Blocks Length: 4, 8, 12, 16 - all MANDATORY for the SNK implementation
- Allocation Method: Loudness, SNR - both MANDATORY for the SNK implementation
- Maximum and minimum bit pool : between 2 to 250, expressed in 8 bit uint
  (Unsigned integer, Most significant bit first) :
   - A2DP spec v1.2 states that requires all SNK implementation shall handle
     bitrates of up to 512 kbps (which correspond to bitpool = 76).
   - A2DP spec v1.3 doesn't specify any bitrate limit, and some high-end SNK
     devices announce bitpool between 62 and 94 (bitpool 94 = 551kbps bitrate).

Bluetooth standard radio capabilities are as follow :

|  Bluetooth speed EDR    | EDR 2Mbps |       | EDR 3Mbps |
|-------------------------|-----------|-------|-----------|
| Speed (b/s)             |   2097152 |       |   3145728 |
| Radio slot length (s)   |  0.000625 |       |  0.000625 |
| Radio slots / s         |      1600 |       |      1600 |
| Slot size (B)           |    163.84 |       |    245.76 |
| Max payload/5 slots (B) |     676.2 |       |    1085.8 |
| max bitrate (Kb/s)      |   1408.75 |       |   2262.08 |

The A2DP specification V1.3 provides RECOMMENDATIONS for bitpool implementation
for the encoder of the SRC : it is required to support AT LEAST the following
settings :

- STEREO MODE : 53
- MONO MODE : 31
- DUAL CHANNEL : unspecified, so let's assume that the MONO value can be used : 3

According to http://soundexpert.org/articles/-/blogs/audio-quality-of-sbc-xq-bluetooth-audio-codec ,
AptX quality can be reached either :

- in STEREO MODE, with bitpool ~ 76
- in DUAL CHANNEL MODE, with bitpool ~ 38 per channel

| sampling Freq (Hz)      |     44100 | 48000 |
|-------------------------|-----------|-------|
| bitpool / channel       |        38 |    35 |
| Frame length DUAL (B)   |       164 |   152 |
| Frame length JST (B)    |       165 |   153 |
| Frame length ST (B)     |       164 |   152 |
| bitrate DUAL CH (kb/s)  |       452 |   456 |
| bitrate JOINT ST (kb/s) |       454 |   459 |
| bitrate STEREO (kb/s)   |       452 |   456 |
