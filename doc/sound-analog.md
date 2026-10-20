# I2S audio - Getting analog sound out from Radxa A7Z board

## I2S generic
[Wikipedia](https://en.wikipedia.org/wiki/I2S)
- audio standard for ADC/DAC/codec devices for the past few decades

Pins and clocks (on 24-bit, 48 kHz):
- DIN				data in, sometimes called DACDAT, DS, DSIN
- LRCK	48 kHz		left-right clock, sometimes called WS
- BCLK	3.072 MHz	bit clock		(64*LRCK)
- MCLK	12.288 MHz	master clock	(4*BCK, 256*LRCK) oversampling clock, used (sometimes) internally by ADC/DAC

# Hardware
[WM8960 codec module](https://www.waveshare.com/wm8960-audio-board.htm)
- [WM8960 datasheet](https://community.nxp.com/pwmxy87654/attachments/pwmxy87654/imx-processors/52419/1/WM8960.pdf) - ADC + DAC with configuration over i2c
- doesn't work
- can be configured over i2c, aplay -l will report it
- I2S signals measured on chip pins with scope
- MCLK was 24 MHz onboard oscillator
- no analog audio output on scope

[DAC 5100 with 2xNS4150 power amps](https://github.com/WeActStudio/WeActStudio.I2SSpeakerModuleV1)
- [TI DAC510x datasheet](https://www.ti.com/lit/ds/symlink/pcm5102a.pdf)
- 3.3V audio and digital
- 16/24/32-bit
- 8 - 384 kHz
- works with or without MCLK
- works with speakers from [Waveshare WM8960 module](https://www.waveshare.com/wm8960-audio-board.htm)
- speaker connector is slighty smaller than 2.54 mm pin header, but nothing that (small amount of) brute force can't fix
- "SD" pin could be used to mute it (connect to GND)

DAC 5102 purple PCB with headphone jack
- line out, but headphones will also work
- config jumpers on the back of the PCB: 1L, 2L, 3H, 4L  
	1 low	FLT		low (normal latency), high (low latency)  
	2 low	DEMP	low (off), high (on) - for 44.1 kHz  
	3 high	XMST	low (soft mute), high (soft unmute)  
	4 low	FMT		low (I2S), high (left justified)  

I2S0 used - only one available on A7Z. I2S1 is not routed from CPU BGA balls.

| A7Z	| I2S		| 5100/5102A module |
|-------|-----------|-------------------|
| PB6		| LRCK	| LRCK/WS
| PB7		| DOUT	| DIN
| PB8		| DIN	| -
| PB4		| MCLK	| SCK/MC (optional)
| PB5		| BCLK	| BCK

## Software
- Linux 6.18, patched mainline kernel (Nick Alilovic)
- Armbian, Debian Trixie on ZFS
- don't remember if kernel was recompiled with some additional CONFIGs
- [dts file](../dtb/overlay/i2s0-dac.dtso)
- loaded modules (automatically):
```
lsmod | grep -iE 'snd|pcm'
snd_soc_sunxi_codec_hdmi    20480  1
snd_soc_sunxi_i2s      61440  4
snd_soc_sunxi_machine    49152  4
snd_soc_sunxi_pcm      28672  1 snd_soc_sunxi_i2s
snd_soc_sunxi_common   110592  4 snd_soc_sunxi_codec_hdmi,snd_soc_sunxi_pcm,snd_soc_sunxi_i2s,snd_soc_sunxi_machine
snd_soc_aw87x_pa       90112  1 snd_soc_sunxi_common
snd_soc_sunxi_codec_av    20480  0
snd_soc_core          217088  7 snd_soc_sunxi_codec_av,snd_soc_sunxi_codec_hdmi,snd_soc_sunxi_pcm,snd_soc_sunxi_common,snd_soc_sunxi_i2s,snd_soc_sunxi_machine,snd_soc_aw87x_pa
snd_pcm_dmaengine      16384  2 snd_soc_sunxi_pcm,snd_soc_core
snd_pcm               139264  5 snd_soc_sunxi_pcm,snd_soc_core,snd_soc_sunxi_machine,snd_pcm_dmaengine
snd_timer              36864  1 snd_pcm
snd                    90112  12 snd_timer,snd_soc_core,snd_soc_sunxi_common,snd_pcm,snd_soc_sunxi_i2s
soundcore              12288  1 snd
```

## Test
```
# cat /proc/asound/cards
0 [pcm5102adac    ]: pcm5102a-dac - pcm5102a-dac
                     pcm5102a-dac
1 [allwinnerhdmi  ]: allwinner-hdmi - allwinner-hdmi
                     allwinner-hdmi

# speaker-test -D hw:0,0 -c 2 -r 48000 -t sine

# mpv -vo=null <file>
```

## Usage
- no software volume control - it is plain DAC, not fancy codec
- no software multiplexing - only one thing can play music (at least for now)
- volume control from CLI, as user:
change default device from HDMI to I2S DAC
```
% pactl info

% pactl get-sink-volume @DEFAULT_SINK@
	Volume: front-left: 65536 / 100% / 0.00 dB,   front-right: 65536 / 100% / 0.00 dB
		balance 0.00

% pactl list short sinks
	0       alsa_output.platform-soc_3000000_i2s3_mach.stereo-fallback      module-alsa-card.c      s16le 2ch 48000Hz       SUSPENDED
	1       alsa_output.platform-soc_3000000_i2s0_mach.stereo-fallback      module-alsa-card.c      s16le 2ch 44100Hz       SUSPENDED

% pactl get-default-sink
	alsa_output.platform-soc_3000000_i2s3_mach.stereo-fallback

% pactl set-default-sink alsa_output.platform-soc_3000000_i2s0_mach.stereo-fallback

% pactl get-default-sink
	alsa_output.platform-soc_3000000_i2s0_mach.stereo-fallback

% pactl get-sink-volume @DEFAULT_SINK@
	Volume: front-left: 45875 /  70% / -9.29 dB,   front-right: 45875 /  70% / -9.29 dB
			balance 0.00

% pactl set-sink-volume @DEFAULT_SINK@ -10%

% pactl get-sink-volume @DEFAULT_SINK@
	Volume: front-left: 39321 /  60% / -13.31 dB,   front-right: 39321 /  60% / -13.31 dB
			balance 0.00
```
- now user can play multiple audio files simultaneously

# History
261019 first commit  
