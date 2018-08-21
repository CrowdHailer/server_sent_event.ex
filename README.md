# ServerSentEvent

[![Build Status](https://secure.travis-ci.org/CrowdHailer/server_sent_event.ex.svg?branch=master
"Build Status")](https://travis-ci.org/CrowdHailer/server_sent_event.ex)

**Push updates to web clients over HTTP, using dedicated server-push protocol.**

- [Install from Hex](https://hex.pm/packages/server_sent_event)
- [Documentation available on hexdoc](https://hexdocs.pm/server_sent_event)

### Server Sent Event Standard

https://html.spec.whatwg.org/#server-sent-events

## Usage

### Parsing and Serializing

```elixir
iex(1)> event = ServerSentEvent.new("my data")
%ServerSentEvent{
  comments: [],
  id: nil,
  lines: ["my data"],
  retry: nil,
  type: nil
}

iex(2)> binary = ServerSentEvent.serialize(event)
"data: my data\n\n"

iex(3)> {:ok, {^event, ""}} = ServerSentEvent.parse(binary)
{:ok,
 {%ServerSentEvent{
    comments: [],
    id: nil,
    lines: ["my data"],
    retry: nil,
    type: nil
  }, ""}}

```

### Client

This project also includes a general purpose client.
See documentation for `ServerSentEvent.Client` for more information.

## Testing

```
git clone git@github.com:CrowdHailer/server_sent_event.ex.git
cd server_sent_event.ex

mix deps.get
mix test
mix dialyzer
```
