---
title: TLS Ticket Requests
abbrev: TLS Ticket Requests
docname: draft-ietf-tls-ticketrequests-latest
date:
category: std

ipr: trust200902
keyword: Internet-Draft

stand_alone: yes
pi: [toc, sortrefs, symrefs]

author:
  -
    ins: T. Pauly
    name: Tommy Pauly
    org: Apple Inc.
    street: One Apple Park Way
    city: Cupertino, California 95014
    country: United States of America
    email: tpauly@apple.com
  -
    ins: D. Schinazi
    name: David Schinazi
    org: Google LLC
    street: 1600 Amphitheatre Parkway
    city: Mountain View, California 94043
    country: United States of America
    email: dschinazi.ietf@gmail.com
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
  RFC8174:

--- abstract

TLS session tickets enable stateless connection resumption for clients without
server-side, per-client state. Servers vend an arbitrary number of session tickets
to clients, at their discretion, upon connection establishment. Clients store and
use tickets when resuming future connections. This document describes a mechanism by
which clients can specify the desired number of tickets needed for future connections.
This extension aims to provide a means for servers to determine the number of tickets
to generate in order to reduce ticket waste, while simultaneously priming clients
for future connection attempts.

--- middle

# Introduction

As per {{!RFC5077}}, and as described in {{RFC8446}}, TLS servers vend clients an arbitrary
number of session tickets at their own discretion in NewSessionTicket messages. There are
at least three limitations with this design.

First, servers vend some (often hard-coded) number of tickets per
connection.  Some server implementations return a different default number of
tickets for session resumption than for the initial full handshake that created
the session.  No static choice, whether fixed, or resumption-dependent is ideal
for all situations.

Second, clients do not have a way of expressing their
desired number of tickets, which can impact future connection establishment.
For example, clients can open multiple TLS connections to the same server for HTTP,
or race TLS connections across different network interfaces. The latter is especially
useful in transport systems that implement Happy Eyeballs {{?RFC8305}}. Since clients control
connection concurrency and resumption, a standard mechanism for requesting more than one
ticket is desirable.

Third, all tickets in the client's possession
ultimately derive from some initial full handshake. Especially when the client
was initially authenticated with a client certificate, that session may need to
be refreshed from time to time. Consequently, a server may periodically
force a full handshake even when the client presents a valid ticket.
When that happens, it is possible that any other tickets derived from the
same original session are equally invalid. A client avoids a full handshake
on subsequent connections if it replaces all stored tickets with
fresh ones obtained from the just performed full handshake. The number of
tickets the server should vend for a full handshake may therefore need to be
larger than the number for routine resumption.

This document specifies a new TLS extension -- "ticket_request" -- that can be used
by clients to express their desired number of session tickets. Servers can use this
extension as a hint of the number of NewSessionTicket messages to vend.
This extension is only applicable to TLS 1.3 {{!RFC8446}}, DTLS 1.3 {{!I-D.ietf-tls-dtls13}},
and future versions thereof.

## Requirements Language

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and
"OPTIONAL" in this document are to be interpreted as described in
{{RFC2119}} {{RFC8174}} when, and only when, they appear in all capitals,
as shown here.

# Use Cases

The ability to request one or more tickets is useful for a variety of purposes:

- Parallel HTTP connections: To minimize ticket reuse while still improving performance, it may
be useful to use multiple, distinct tickets when opening parallel connections. Clients must
therefore bound the number of parallel connections they initiate by the number of tickets
in their possession, or risk ticket re-use.
- Connection racing: Happy Eyeballs V2 {{?RFC8305}} describes techniques for performing connection
racing. The Transport Services Architecture implementation from {{?TAPS=I-D.ietf-taps-impl}} also describes
how connections can race across interfaces and address families. In such cases, clients may use
more than one ticket while racing connection attempts in order to establish one successful connection.
Having multiple tickets equips clients with enough tickets to initiate connection racing while
avoiding ticket re-use and ensuring that their cache of tickets does not empty during such races.
Moreover, as some servers may implement single-use tickets, distinct tickets prevent
premature ticket invalidation by racing.
- Connection priming: In some systems, connections can be primed or bootstrapped by a centralized
service or daemon for faster connection establishment. Requesting tickets on demand allows such
services to vend tickets to clients to use for accelerated handshakes with early data. (Note that
if early data is not needed by these connections, this method SHOULD NOT be used. Fresh handshakes
SHOULD be performed instead.)
- Less ticket waste: Currently, TLS servers use application-specific, and often implementation-specific,
logic to determine how many tickets to issue. By moving the burden of ticket count to clients,
servers do not generate wasteful tickets. As an example, clients might only request one ticket during
resumption. Moreover, as ticket generation might involve expensive computation, e.g., public key
cryptographic operations, avoiding waste is desirable.
- Decline resumption: Clients can indicate they have no intention of resuming connections by
sending a ticket request with count of zero.

# Ticket Requests

As discussed in {{introduction}}, clients may want different numbers of tickets
for fresh or resumed handshakes. Clients may indicate to servers their desired
number of tickets for a single connection, in the case of a full handshake or
resumption, via the following "ticket_request" extension:

~~~
enum {
    ticket_request(TBD), (65535)
} ExtensionType;
~~~

Clients MAY send this extension in ClientHello. It contains the following structure:

~~~
struct {
    uint8 new_session_count;
    uint8 resumption_count;
} ClientTicketRequest;

struct {
    uint8 expected_count;
} ServerTicketRequest;

struct {
    select (Handshake.msg_type) {
        case client_hello: ClientTicketRequest;
        case encrypted_extensions: ServerTicketRequest;
    }
} TicketRequestContents;
~~~

new_session_count
: The number of tickets desired by the client when the server chooses to
negotiate a fresh session (full handshake).

resumption_count
: The number of tickets desired by the client when the server is willing to
resume using the presented ticket.

expected_count
: The number of tickets the server expects to send in response to a client
ticket_request extension.

A client starting a fresh connection SHOULD set new_session_count to the desired
number of session tickets and resumption_count to 0.
Once a client's ticket cache is primed, a resumption_count of 1 is a
good choice that allows the server to replace each ticket with a fresh ticket,
without over-provisioning the client with excess tickets. However, clients
which race multiple connections and place a separate ticket in each will
ultimately end up with just the tickets from a single resumed session.
In that case, clients SHOULD send a resumption_count equal to the number
of sessions they are attempting in parallel.

When a client presenting a previously obtained ticket finds that the server
nevertheless negotiates a fresh session, the client might assume that any
other tickets associated with the same session as the presented ticket are also
no longer valid for resumption.  This includes tickets obtained
during the initial full handshake and all tickets subsequently obtained as
part of subsequent resumptions.  Requesting more than one ticket in case a
full handshake is forced by the server helps to keep the session cache primed.

Servers SHOULD NOT send more tickets than requested for the handshake type
selected by the server (resumption or full handshake). Moreover, servers
SHOULD place a limit on the number of tickets they are willing to send, whether
for full handshakes or resumptions, to save resources.  Therefore, the
number of NewSessionTicket messages sent will typically be the minimum
of the server's self-imposed limit and the number requested.

A server that supports ticket requests MAY echo the "ticket_request" extension
in the EncryptedExtensions message. If present, it contains a single
value, expected_count, indicating the number of tickets the server expects to
send to the client.

Servers MUST NOT send the "ticket_request" extension in ServerHello or HelloRetryRequest messages.
A client MUST abort the connection with an "illegal_parameter" alert if the "ticket_request" extension
is present in either of these messages.

If a client receives a HelloRetryRequest, the presence (or absence) of the "ticket_request" extension
MUST be maintained in the second ClientHello message. Moreover, if this extension is present, a client
MUST NOT change the value of TicketRequestContents in the second ClientHello message.

# IANA Considerations

IANA is requested to Create an entry, ticket_request(TBD), in the existing registry
for ExtensionType (defined in {{RFC8446}}), with "TLS 1.3" column values being set to
"CH, EE", and "Recommended" column being set to "Yes".

# Performance Considerations

Servers can send tickets in NewSessionTicket messages any time after the
server Finished message (see {{RFC8446}}; Section 4.6.1). A server which
chooses to send a large number of tickets to a client
can potentially harm application performance if the tickets are sent before application data.
For example, if the transport connection has a constrained congestion window, ticket
messages could delay sending application data. To avoid this, servers should
prioritize sending application data over tickets when possible.

# Security Considerations

Ticket re-use is a security and privacy concern. Moreover, clients must take care when pooling
tickets as a means of avoiding or amortizing handshake costs. If servers do not rotate session
ticket encryption keys frequently, clients may be encouraged to obtain
and use tickets beyond common lifetime windows of, e.g., 24 hours. Despite ticket lifetime
hints provided by servers, clients SHOULD dispose of pooled tickets after some reasonable
amount of time that mimics the ticket rotation period.

In some cases, a server may send NewSessionTicket messages immediately upon sending
the server Finished message rather than waiting for the client Finished. If the server
has not verified the client's ownership of its IP address, e.g., with the TLS
Cookie extension (see {{RFC8446}}; Section 4.2.2), an attacker may take advantage of this behavior to create
an amplification attack proportional to the count value toward a target by performing a key
exchange over UDP with spoofed packets. Servers SHOULD limit the number of NewSessionTicket messages they send until they have verified the client's ownership of its IP address.

Servers that do not enforce a limit on the number of NewSessionTicket messages sent in response
to a "ticket_request" extension could leave themselves open to DoS attacks, especially if ticket
creation is expensive.

# Acknowledgments

The authors would like to thank David Benjamin, Eric Rescorla, Nick Sullivan, Martin Thomson,
Hubert Kario, and other members of the TLS Working Group for discussions on earlier versions of
this draft. Viktor Dukhovni contributed text allowing clients to send multiple
counts in a ticket request.
