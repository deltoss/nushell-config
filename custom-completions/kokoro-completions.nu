# Auto-generated

def "nu-complete kokoro none" [] {
  []
}

def "nu-complete kokoro log-level" [] {
  [debug info warn error]
}

def "nu-complete kokoro device" [] {
  [cpu wasm webgpu]
}

# Custom CLI wrapper around kokoro.js
@example "Generate speech" { kokoro -o speech.wav 'Hello from Kokoro' }
@example "Read text from stdin" { 'Hello from stdin' | kokoro -o speech.wav }
@example "Choose a voice" { kokoro --voice af_bella -o speech.wav 'Hello' }
export extern kokoro [
  ...words: string@"nu-complete kokoro none" # Words to process
  -h, --help # Show this help.
  --debug # Enable debug output.
  -l, --log-level: string@"nu-complete kokoro log-level" # Set log level. (default: info)
  -o, --output: path # The file to save the TTS output to. (required)
  -v, --voice: string@"nu-complete kokoro none" # The voice to use. See https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX#samples (default: af_heart)
  -m, --model: string@"nu-complete kokoro none" # The model to use. (default: onnx-community/Kokoro-82M-v1.0-ONNX)
  -d, --device: string@"nu-complete kokoro device" # The device to use for the TTS. 'wasm', 'webgpu' (web) or 'cpu' (node). If using 'webgpu', we recommend using dtype='fp32'. (default: cpu)
]
