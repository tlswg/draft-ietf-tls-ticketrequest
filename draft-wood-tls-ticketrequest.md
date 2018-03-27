---
title: TLS Ticket Request
abbrev: TLS Ticket Request
docname: draft-wood-tls-ticketrequest-latest
date:
category: info

ipr: trust200902
keyword: Internet-Draft

stand_alone: yes
pi: [toc, sortrefs, symrefs]

author:
  -
    ins: C. A. Wood
    name: Christopher A. Wood
    org: Apple Inc.
    street: 1 Infinite Loop
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

TLS session tickets are produced by servers to permit stateless session resumption for clients. 
Moreover, servers often distribute at most one or two tickets to each client. As a matter
of security and privacy concerns, clients should only use tickets once, especially if 
tickets are used to protect early application data in TLS 1.3 and related protocols. 
However, single tickets limit a client's ability to perform Happy Eyeball-style connection racing, 
as multiple competing connections should not re-use the same ticket more than once. 
This document describes a mechanism that enables the clients to request multiple TLS 
session tickets from the server so as to enable such features.

--- middle

# Introduction

As per {{RFC5077}}, and as described in {{I-D.ietf-tls-tls13}}, 
TLS servers send clients session tickets at their own discretion in NewSessionTicket messages. 
In contrast, clients are in complete control of how many tickets they may use when establishing 
future connections. For example, clients may open multiple TLS connections to the same server
for HTTP, or may race TLS connections across different network interfaces. 
The latter is especially useful in transport systems that implement Happy Eyeballs {{RFC8305}}.
Thus, since connection concurrency and resumption is controlled by clients, a mechanism to request 
tickets on demand is desirable. In this document, we describe a new TLS extension and handshake 
message that permits clients to request new session tickets at will from the server.

This document specifies two new  TLS handshake messages -- TicketRequest and TicketResponse -- 
that may be used to request tickets and receive TLS tickets. Ticket requests may carry optional 
application contexts to limit the ways in which tickets may be used.

## Requirements Language

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in RFC 2119 {{RFC2119}}.

# Use Cases

The ability to request one or more tickets is useful for a variety of purposes:

- Parallel HTTP connections: To minimize ticket reuse while still improving performance, it may
be useful to use multiple separate tickets when opening parallel connections. If servers do not
vend more than one ticket, clients are forced to restrict the number of parallel connections
or re-use tickets. 
- Connection racing: Happy Eyeballs V2 {{RFC8305}} describes techniques for performing connection
racing. The Transport Services Architecture implementation from {{I-D.brunstrom-taps-impl}} also describes how 
connections may race across interfaces and address families. In cases where clients have early
data to send and want to minimize or avoid ticket re-use, unique tickets for each unique
connection attempt are useful.
- Connection priming: In some systems, connections may be primed or bootstrapped by a centralized
service or daemon for faster connection establishment. Requesting tickets on demand allows such
services to vend tickets to clients to use for accelerated handshakes with early data. (Note that
if early data is not needed by these connections, this method SHOULD NOT be used. Fresh handshakes
SHOULD be performed instead.)
- Less ticket waste: Currently, TLS servers use application-specific, and often implementation-specific,
logic to determine how many tickets to issue. By moving the burden of ticket count to clients,
servers do not generate wasteful tickets for clients.

# Ticket Requests

TLS tickets may be requested via a TicketRequest handshake message, ticket_request(TBD). 
Its structure is shown below.

~~~
struct {
    opaque identifier<0..255>;
    opaque request_context<0..2^16-1>;
} TicketRequest;
~~~

- identifier: A unique value for this ticket request. Clients SHOULD fill this in with
a monotonically increasing counter.

- request_context: An opaque context to be used when generating the ticket request.
Clients and servers may use this context to implement or exchange data to be included in the
ticket computation. Clients SHOULD make this field empty if it is not needed.

Upon receipt of a TicketRequest message, servers MAY reply with a TicketResponse message,
ticket_response(TBD). Its structure is shown below.

~~~
struct {
    opaque identifier<0..255>;
    opaque response_context<0..2^16-1>;
    NewSessionTicket ticket;
} TicketResponse;
~~~

- identifier: A unique value for the response that MUST match the corresponding client
TicketRequest.

- response_context: An opaque context to be used when generating each ticket for the request.
Servers MUST make this field empty if the corresponding TicketRequest request_context is empty.

- ticket: A NewSessionTicket message, encoded as detailed in {{I-D.ietf-tls-tls13}}. 

When a server S receives a TicketRequest with new identifier N it SHOULD generate a new ticket and 
cache it locally for some period of time T. If S receives a TicketRequest with identifier N
within time period T, S MUST reply with the same ticket previously generated. (This is to help deal
with request retransmissions from the client.) If S receives a TicketRequest with identifier N
outside time period T, S SHOULD reply with an empty TicketResponse, i.e., a TicketResponse with
identifier N, appropriate response_context, and empty ticket field.

Servers SHOULD place a limit on the number of tickets they are willing to vend to clients. Servers
MUST NOT send more than 255 tickets to clients, as this is the limit imposed by the request and 
response identifier size. TicketRequest messages MUST NOT be sent until after the TLS handshake 
is complete. As handshake messages, these MUST be added to the handshake transcript.

# Negotiation 

Clients negotiate use of ticket requests via a new ExtensionType, ticket_request(TBD). 
The extension_data for this extension MUST be empty (have a 0 length). Servers that support ticket 
requests MAY echo this extension in the EncryptedExtensions. Clients MUST NOT send ticket requests to servers
that do not signal support for this message. If absent from a ClientHello, servers MUST NOT generate 
responses to TicketRequests issued by the client.

# IANA Considerations

((TODO: codepoint for handshake message type))

# Security Considerations

Ticket re-use is a privacy and security concern. Moreover, pre-fetching as a means of
avoiding or amortizing the cost of handshakes must also be used carefully. If servers
do not rotate session ticket encryption keys frequently, clients may be encouraged to obtain
and use tickets beyond common lifetime windows of, e.g., 24 hours. Despite ticket lifetime
hints provided by servers, clients SHOULD dispose of pre-fetched tickets after some reasonable
amount of time that mimics the ticket rotation period. 

# Acknowledgments

The authors would like to thank Eric Rescorla and Nick Sullivan for discussions on earlier 
versions of this draft.
