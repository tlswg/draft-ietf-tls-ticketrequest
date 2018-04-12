---
title: TLS Ticket Requests
abbrev: TLS Ticket Requests
docname: draft-wood-tls-ticketrequests-latest
date:
category: info

ipr: trust200902
keyword: Internet-Draft

stand_alone: yes
pi: [toc, sortrefs, symrefs]

author:
  -
    ins: D. Schinazi
    name: David Schinazi
    org: Apple Inc.
    street: One Apple Park Way
    city: Cupertino, California 95014
    country: United States of America
    email: dschinazi@apple.com
  -
    ins: T. Pauly
    name: Tommy Pauly
    org: Apple Inc.
    street: One Apple Park Way
    city: Cupertino, California 95014
    country: United States of America
    email: tpauly@apple.com
  -
    ins: C. A. Wood
    name: Christopher A. Wood
    org: Apple Inc.
    street: One Apple Park Way
    city: Cupertino, California 95014
    country: United States of America
    email: cawood@apple.com

normative:
  RFC2119:
  RFC5077:
  RFC8305:
  I-D.brunstrom-taps-impl:
  I-D.ietf-tls-tls13:

--- abstract

TLS session tickets enable stateless connection resumption for clients without
server-side per-client state. Servers vend session tickets to clients, at their 
discretion, upon connection establishment. Clients store and use tickets when 
resuming future connections. Moreover, clients should use tickets at most once for
session resumption, especially if such keying material protects early application 
data. Single-use tickets bound the number of parallel connections a client
may initiate by the number of tickets received from a given server. To address
this limitation, this document describes a mechanism by which clients may request 
tickets as needed during a connection.

--- middle

# Introduction

As per {{RFC5077}}, and as described in {{I-D.ietf-tls-tls13}}, 
TLS servers send clients session tickets at their own discretion in NewSessionTicket messages. 
Clients are in complete control of how many tickets they may use when establishing 
future and subsequent connections. For example, clients may open multiple TLS connections to the same server
for HTTP, or may race TLS connections across different network interfaces. 
The latter is especially useful in transport systems that implement Happy Eyeballs {{RFC8305}}.
Since connection concurrency and resumption is controlled by clients, a mechanism to request 
tickets on demand is desirable. 

This document specifies a new TLS post-handshake message -- TicketRequest -- 
that may be used to request tickets via NewSessionTicket messages in TLS 1.3. 
Ticket requests may carry optional application-specific contexts to define the ways in 
which tickets may be used. NewSessionTicket responses reciprocate this application 
context in an extension. 

## Requirements Language

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in RFC 2119 {{RFC2119}}.

# Use Cases

The ability to request one or more tickets is useful for a variety of purposes:

- Parallel HTTP connections: To minimize ticket reuse while still improving performance, it may
be useful to use multiple, distinct tickets when opening parallel connections. Clients must 
therefore bound the number of parallel connections they initiate by the number of tickets
in their possession, or risk ticket re-use.
- Connection racing: Happy Eyeballs V2 {{RFC8305}} describes techniques for performing connection
racing. The Transport Services Architecture implementation from {{I-D.brunstrom-taps-impl}} also describes how 
connections may race across interfaces and address families. In cases where clients have early
data to send and want to minimize or avoid ticket re-use, unique tickets for each unique
connection attempt are useful. Moreover, as some servers may implement single-use tickets (and even
session ticket encryption keys), distinct tickets will be needed to prevent premature ticket 
invalidation by racing.
- Connection priming: In some systems, connections may be primed or bootstrapped by a centralized
service or daemon for faster connection establishment. Requesting tickets on demand allows such
services to vend tickets to clients to use for accelerated handshakes with early data. (Note that
if early data is not needed by these connections, this method SHOULD NOT be used. Fresh handshakes
SHOULD be performed instead.)
- Less ticket waste: Currently, TLS servers use application-specific, and often implementation-specific,
logic to determine how many tickets to issue. By moving the burden of ticket count to clients,
servers do not generate wasteful tickets for clients.

# Ticket Requests

TLS tickets may be requested via a TicketRequest post-handshake message, ticket_request(TBD). 
Its structure is shown below.

~~~
struct {
    opaque identifier<0..255>;
    opaque context<0..2^16-1>;
} TicketRequest;
~~~

- identifier: A unique value for this ticket request. Clients SHOULD fill this in with
a monotonically increasing counter.

- context: An opaque context to be used when generating the ticket request.
Clients and servers may use this context to implement or exchange data to be included in the
ticket computation. Clients SHOULD make this field empty if it is not needed.

Upon receipt of a TicketRequest message, servers MAY reply with a NewSessionTicket message,
as defined in {{I-D.ietf-tls-tls13}}. The latter message MUST carry two extensions, 
ticket_identifer and ticket_context, defined below.

~~~
enum {
    ...
    ticket_identifier(TBD),
    ticket_context(TBD+1),
    (65535)
} ExtensionType;
~~~

The value of ticket_identifier MUST match that of the corresponding TicketRequest identifier
field. The value of ticket_context MAY be used by servers to convey ticket context
to clients. Its value MUST be empty if the corresponding TicketRequest context field is empty.

When a server S receives a TicketRequest with new identifier N it MUST generate a new ticket and SHOULD
cache it locally for some period of time T. If S receives a TicketRequest with identifier N
within time period T, S SHOULD reply with the same ticket previously generated (and cached). 
(This is to help deal with client request retransmissions.) If S receives a TicketRequest with identifier 
N outside time period T, S SHOULD reply with an empty NewSessionTicket, i.e., a NewSessionTicket 
with extension ticket_identifier carrying N, appropriate ticket_context extension, and empty ticket 
field.

Servers SHOULD place a limit on the number of tickets they are willing to vend to clients. Servers
MUST NOT send more than 255 tickets to clients, as this is the limit imposed by the request and 
response identifier size. Lastly, servers SHOULD NOT send unsolicited NewSessionTickets to clients 
that express support for TicketRequests.

<!-- TicketRequest messages MUST NOT be sent until after the TLS handshake is complete.  -->
<!-- As handshake messages, these MUST be added to the handshake transcript. -->

# Negotiation 

Clients negotiate use of ticket requests via a new ExtensionType, ticket_request(TBD). 
The extension_data for this extension MUST be empty, i.e., have length of 0. Servers that support ticket 
requests MAY echo this extension in the EncryptedExtensions. Clients MUST NOT send ticket requests to servers
that do not signal support for this message. If absent from a ClientHello, servers MUST NOT generate 
responses to TicketRequests issued by the client.

# IANA Considerations

((TODO: codepoint for post-handshake message type and extensions))

# Security Considerations

Ticket re-use is a security and privacy concern. Moreover, pre-fetching as a means of
avoiding or amortizing handshake costs must be used carefully. If servers
do not rotate session ticket encryption keys frequently, clients may be encouraged to obtain
and use tickets beyond common lifetime windows of, e.g., 24 hours. Despite ticket lifetime
hints provided by servers, clients SHOULD dispose of pre-fetched tickets after some reasonable
amount of time that mimics the ticket rotation period. 

# Acknowledgments

The authors would like to thank Eric Rescorla, Martin Thomson, and Nick Sullivan for 
discussions on earlier versions of this draft.
