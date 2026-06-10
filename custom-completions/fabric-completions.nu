# Dynamic completers
def "nu-complete fabric patterns" [] {
  # Empty stdin prevents fabric from blocking when stdin is a non-tty pipe
  "" | ^fabric --listpatterns --shell-complete-list | lines | str trim | where $it != ""
}

def "nu-complete fabric models" [] {
  "" | ^fabric --listmodels --shell-complete-list | lines | str trim | where $it != ""
}

def "nu-complete fabric contexts" [] {
  "" | ^fabric --listcontexts --shell-complete-list | lines | str trim | where $it != ""
}

def "nu-complete fabric sessions" [] {
  "" | ^fabric --listsessions --shell-complete-list | lines | str trim | where $it != ""
}

def "nu-complete fabric strategies" [] {
  "" | ^fabric --liststrategies --shell-complete-list | lines | str trim | where $it != ""
}

# Static enum completers
def "nu-complete fabric image-size" [] {
  [1024x1024, 1536x1024, 1024x1536, auto]
}

def "nu-complete fabric image-quality" [] {
  [low, medium, high, auto]
}

def "nu-complete fabric image-background" [] {
  [opaque, transparent]
}

def "nu-complete fabric thinking" [] {
  [off, low, medium, high]
}

# Empty completer to suppress file path fallback on the message positional
def "nu-complete none" [] { [] }

# fabric is an open-source framework for augmenting humans using AI
export extern "fabric" [
  ...message: string@"nu-complete none"                  #Message text sent to the model (appended to stdin input)
  --pattern (-p): string@"nu-complete fabric patterns"   #Choose a pattern from the available patterns
  --variable (-v): string                                #Values for pattern variables, e.g. -v=#role:expert -v=#points:30
  --context (-C): string@"nu-complete fabric contexts"   #Choose a context from the available contexts
  --session: string@"nu-complete fabric sessions"        #Choose a session from the available sessions
  --attachment (-a): path                                #Attachment path or URL (e.g. for OpenAI image recognition messages)
  --setup (-S)                                           #Run setup for all reconfigurable parts of fabric
  --temperature (-t): float                              #Set temperature (default: 0.7)
  --topp (-T): float                                     #Set top P (default: 0.9)
  --stream (-s)                                          #Stream
  --presencepenalty (-P): float                          #Set presence penalty (default: 0.0)
  --raw (-r)                                             #Use model defaults without sending chat options (OpenAI-compatible providers only)
  --frequencypenalty (-F): float                         #Set frequency penalty (default: 0.0)
  --listpatterns (-l)                                    #List all patterns
  --readpattern: string@"nu-complete fabric patterns"    #Print the contents of the named pattern to the terminal
  --listmodels (-L)                                      #List all available models
  --listcontexts (-x)                                    #List all contexts
  --listsessions (-X)                                    #List all sessions
  --updatepatterns (-U)                                  #Update patterns
  --copy (-c)                                            #Copy to clipboard
  --model (-m): string@"nu-complete fabric models"       #Choose model
  --vendor (-V): string                                  #Specify vendor for the selected model (e.g., -V "LM Studio" -m openai/gpt-oss-20b)
  --modelContextLength: int                              #Model context length (only affects ollama)
  --output (-o): path                                    #Output to file
  --output-session                                       #Output the entire session (also a temporary one) to the output file
  --latest (-n): int                                     #Number of latest patterns to list
  --changeDefaultModel (-d)                              #Change default model
  --youtube (-y): string                                 #YouTube video or playlist URL to grab transcript/comments from and send to chat
  --playlist                                             #Prefer playlist over video if both ids are present in the URL
  --transcript                                           #Grab transcript from YouTube video and send to chat (default)
  --transcript-with-timestamps                           #Grab transcript from YouTube video with timestamps and send to chat
  --visual                                               #Extract visual data from video using OCR and FFmpeg
  --visual-sensitivity: float                            #Tolerance for FFmpeg scene detection (0.0 - 1.0) (default: 0.4)
  --visual-fps: int                                      #Extract a specific number of frames per second instead of scene detection
  --comments                                             #Grab comments from YouTube video and send to chat
  --metadata                                             #Output video metadata
  --yt-dlp-args: string                                  #Additional arguments to pass to yt-dlp (e.g. '--cookies-from-browser brave')
  --spotify: string                                      #Spotify podcast or episode URL to grab metadata from and send to chat
  --language (-g): string                                #Specify the Language Code for the chat, e.g. -g=en -g=zh -g=pt-BR
  --scrape_url (-u): string                              #Scrape website URL to markdown using Jina AI
  --scrape_question (-q): string                         #Search question using Jina AI
  --seed (-e): int                                       #Seed to be used for LMM generation
  --wipecontext (-w): string@"nu-complete fabric contexts" #Wipe context
  --wipesession (-W): string@"nu-complete fabric sessions" #Wipe session
  --printcontext: string@"nu-complete fabric contexts"   #Print context
  --printsession: string@"nu-complete fabric sessions"   #Print session
  --readability                                          #Convert HTML input into a clean, readable view
  --input-has-vars                                       #Apply variables to user input
  --no-variable-replacement                              #Disable pattern variable replacement
  --dry-run                                              #Show what would be sent to the model without actually sending it
  --serve                                                #Serve the Fabric Rest API
  --serveOllama                                          #Serve the Fabric Rest API with ollama endpoints
  --address: string                                      #The address to bind the REST API (default: :8080)
  --api-key: string                                      #API key used to secure server routes
  --config: path                                         #Path to YAML config file
  --version                                              #Print current version
  --listextensions                                       #List all registered extensions
  --addextension: path                                   #Register a new extension from config file path
  --rmextension: string                                  #Remove a registered extension by name
  --strategy: string@"nu-complete fabric strategies"     #Choose a strategy from the available strategies
  --liststrategies                                       #List all strategies
  --listvendors                                          #List all vendors
  --shell-complete-list                                  #Output raw list without headers/formatting (for shell completion)
  --search                                               #Enable web search tool for supported models (Anthropic, OpenAI, Gemini)
  --search-location: string                              #Set location for web search results (e.g., 'America/Los_Angeles')
  --image-file: path                                     #Save generated image to specified file path (e.g., 'output.png')
  --image-size: string@"nu-complete fabric image-size"   #Image dimensions: 1024x1024, 1536x1024, 1024x1536, auto (default: auto)
  --image-quality: string@"nu-complete fabric image-quality" #Image quality: low, medium, high, auto (default: auto)
  --image-compression: int                               #Compression level 0-100 for JPEG/WebP formats
  --image-background: string@"nu-complete fabric image-background" #Background type: opaque, transparent (PNG/WebP only)
  --suppress-think                                       #Suppress text enclosed in thinking tags
  --think-start-tag: string                              #Start tag for thinking sections (default: <think>)
  --think-end-tag: string                                #End tag for thinking sections (default: </think>)
  --disable-responses-api                                #Disable OpenAI Responses API (default: false)
  --transcribe-file: path                                #Audio or video file to transcribe
  --transcribe-model: string                             #Model to use for transcription (separate from chat model)
  --split-media-file                                     #Split audio/video files larger than 25MB using ffmpeg
  --voice: string                                        #TTS voice name for supported models (e.g., Kore, Charon, Puck) (default: Kore)
  --list-gemini-voices                                   #List all available Gemini TTS voices
  --list-transcription-models                            #List all available transcription models
  --notification                                         #Send desktop notification when command completes
  --notification-command: string                         #Custom command to run for notifications (overrides built-in)
  --thinking: string@"nu-complete fabric thinking"       #Set reasoning/thinking level (off, low, medium, high, or numeric tokens)
  --show-metadata                                        #Print metadata to stderr
  --debug: int                                           #Set debug level (0=off, 1=basic, 2=detailed, 3=trace, 4=wire)
  --help (-h)                                            #Show this help message
]