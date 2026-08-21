import {existsSync, mkdirSync, writeFileSync} from 'node:fs';
import {join, resolve} from 'node:path';

const sampleRate = 44100;
const outputDirectory = process.argv[2];

if (!outputDirectory) {
	throw new Error('Usage: node generate-basic-sfx.mjs <output-directory>');
}

const encodeWav = (samples) => {
	const buffer = Buffer.alloc(44 + samples.length * 2);
	buffer.write('RIFF', 0);
	buffer.writeUInt32LE(36 + samples.length * 2, 4);
	buffer.write('WAVEfmt ', 8);
	buffer.writeUInt32LE(16, 16);
	buffer.writeUInt16LE(1, 20);
	buffer.writeUInt16LE(1, 22);
	buffer.writeUInt32LE(sampleRate, 24);
	buffer.writeUInt32LE(sampleRate * 2, 28);
	buffer.writeUInt16LE(2, 32);
	buffer.writeUInt16LE(16, 34);
	buffer.write('data', 36);
	buffer.writeUInt32LE(samples.length * 2, 40);
	samples.forEach((sample, index) => {
		const value = Math.max(-1, Math.min(1, sample));
		buffer.writeInt16LE(Math.round(value * 32767), 44 + index * 2);
	});
	return buffer;
};

let randomState = 17;
const noise = () => {
	randomState = (randomState * 16807) % 2147483647;
	return randomState / 1073741823.5 - 1;
};

const synthesize = (seconds, sample) =>
	Float32Array.from({length: Math.round(seconds * sampleRate)}, (_, index) =>
		sample(index / sampleRate, index / (seconds * sampleRate)),
	);

const sounds = {
	'whoosh.wav': synthesize(0.42, (_time, progress) => {
		const envelope = Math.sin(Math.PI * progress) ** 2;
		return noise() * envelope * 0.32;
	}),
	'click.wav': synthesize(0.08, (time, progress) =>
		Math.sin(2 * Math.PI * 1500 * time) * Math.exp(-progress * 12) * 0.5,
	),
	'impact.wav': synthesize(0.5, (time, progress) => {
		const frequency = 95 - progress * 45;
		return Math.sin(2 * Math.PI * frequency * time) * Math.exp(-progress * 6) * 0.8;
	}),
};

const destination = resolve(outputDirectory);
const existing = Object.keys(sounds).filter((name) =>
	existsSync(join(destination, name)),
);

if (existing.length > 0) {
	throw new Error(`Refusing to overwrite: ${existing.join(', ')}`);
}

mkdirSync(destination, {recursive: true});
for (const [name, samples] of Object.entries(sounds)) {
	writeFileSync(join(destination, name), encodeWav(samples));
}

console.log(`Wrote ${Object.keys(sounds).join(', ')} to ${destination}`);
