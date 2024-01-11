# chatgpt.tcl for eggdrop
# Version: 0.2 - 11/01/2024
# Author: workaround <github.com/workaround>
#
# Description:
# This is a simple script that connects to OpenAI
# endpoint to answer questions.
#
# Based on ZarTek-Creole's script which can be found at
# https://github.com/ZarTek-Creole/TCL-CHAT-OPENAI
#
# NOTE: You can obtain API key from OpenAI's platform
# https://platform.openai.com/account/api-keys
#
### Config Section ###
set api_key "sk-XXXXXXXXXXXXXXX"
set endpoint "https://api.openai.com/v1/chat/completions"
set model "gpt-3.5-turbo"
### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING! ###

### PACKAGE
package require json
package require json::write
package require http
package require tls
http::register https 443 [list ::tls::socket -autoservername true]

### BIND
bind pub - !openai openai

### PROC
proc openai {nick host hand chan text} {
  # Make settings accessible
  global api_key endpoint model
  # Extract the prompt from the text
  set prompt [encoding convertto utf-8 [json::write string $text]]
  # Set the payload for the HTTP request
  set payload "{\"model\": \"$model\", \"messages\": \[{\"role\": \"user\", \"content\": $prompt}\], \"temperature\": 0.7,\
               \"max_tokens\": 1000, \"top_p\": 1, \"frequency_penalty\": 0, \"presence_penalty\": 0}"
  # Set the headers for the HTTP request
  set headers [list Authorization "Bearer $api_key"]
  # Make the HTTP request
  if {[catch {set response [http::data [http::geturl $endpoint -headers $headers -query $payload -type "application/json"]]} error]} {
    putlog "Error making HTTP request: $error"
    return
  }
  # Parse the JSON response
  if {[catch {set json [json::json2dict $response]} error]} {
    putlog "Error parsing JSON response: $error"
    return
  }
  # OpenAI has encountered an error
  if {[dict exists $json error]} {
    putlog "Error from OpenAI: [encoding convertfrom utf-8 [dict get $json error message]]"
    return
  }
  # Get the response text from the JSON result
  set message [string map {"\n" " "} [encoding convertfrom utf-8 [dict get [lindex [dict get $json choices] 0] message content]]]
  # Send the response to the channel
  if {$message == ""} {
    send_response $chan "Sorry, I couldn't understand your question"
  } else {
    send_response $chan "$message"
  }
}

# A helper procedure to send a response to the channel
proc send_response {chan text} {
  global botname
  set max_chars [expr 500 - [string length ":$botname PRIVMSG $chan :"]]
  set len [string length $text]
  set start 0
  set end 0
  set substrings {}
  while {$end < $len} {
    set end [expr {$start + $max_chars}]
    if {$end >= $len} {
      set end $len
    } else {
      set lastspace [string last " " [string range $text $start $end]]
      if {$lastspace > $start} {
        set end [expr {$start + $lastspace}]
      }
    }
    lappend substrings [string range $text $start $end]
    set start [expr {$end + 1}]
  }
  foreach sub $substrings {
    putserv "PRIVMSG $chan :$sub"
  }
}

putlog "Script loaded: chatgpt"
