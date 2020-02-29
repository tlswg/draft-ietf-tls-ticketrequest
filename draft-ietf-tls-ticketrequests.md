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
two limitations with this design.

First, servers choose some (often hard-coded) number of tickets vended per
connection.  Some servers (e.g. OpenSSL) return a different default number of
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

Third, we should note that the various tickets in the client's possession
ultimately derive from an initial full handshake.  Especially when the client
was initially authenticated with a client certificate, that session may need to
be refreshed from time to time.  Consequently, a server may periodically
perform a full handshake even when the client presents a valid ticket for a
session that is too old.  When that happens a client should replace all its
cached tickets with fresh ones obtained from the full handshake.  The
number of tickets the server should vend for a full handshake may therefore
need to be larger than the number for routine resumption.

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
Requesting multiple tickets a priori equips clients with enough tickets to initiate connection racing while
avoiding ticket re-use and ensuring that their cache of tickets does not empty during such races.
Moreover, as some servers may implement single-use tickets (and even session ticket encryption keys),
distinct tickets will be needed to prevent premature ticket invalidation by racing.
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

As noted earlier, clients that ask for only a modest ticket count on resumption
risk getting insufficiently many tickets if a full handshake proves necessary,
which invalidates not only the just consumed ticket, but all outstanding
tickets.  Therefore, in order for the extension to correctly handle both
routine resumption and an unanticipated full handshake, the client sends
two separate numbers.  The number of tickets the server should return on
resumption, and the number on a full handshake.

# Ticket Requests

Clients can indicate to servers their desired number of tickets for a single connection via the
following "ticket_request" extension:

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
} TicketRequestContents;
~~~

new_session_count
: The number of tickets desired by the client when the server chooses to
negotiate a fresh session (full handshake), thereby implicitly invalidating all
other tickets sharing the same initial session as the presented ticket.  This
is also the ticket count requested when the client presented no initial ticket
making a full handshake unavoidable.

resumption_count
: The number of tickets desired by the client when the server is willing to
resume the associated session.

Clients can use the above structure to indicate the number of tickets they
would prefer to receive when sessions are resumed or new sessions are
negotiated.

Typically, once a client's ticket cache is primed, a resumption count of 1 is a
good choice that allows the server to replace each ticket with a fresh ticket,
without over-provisioning the client with excess tickets.  However, clients that
are racing multiple connections placing a separate ticket in each, will
ultimately end up with just the tickets from a single resumed session, so
in that case a resumption_count commensurate with the number of parallel
sessions would be used.

On the other hand, with e.g. server-to-server traffic with fixed source
addresses and no connection racing, ticket reuse may be appropriate.  Clients
that wish to reuse tickets when possible should send an extension with the
resumption_count set to 0, and the new_session_count set to the value desired
for a full handshake (typically 1).

Servers SHOULD NOT send more tickets than requested for the handshake type
selected by the server (resumption or full handshake) as clients will most
likely discard any additional tickets.

When a resumption is performed, and the requested resumption_count is zero, the
client is requesting ticket reuse.  If the presented ticket is valid for
additional resumptions (only possible when the server supports reuse), it
SHOULD return no tickets.  Otherwise, when either the server does not support
reuse, or the ticket is expiring, and needs to be replaced (e.g. reissued under
a fresh session-ticket encryption key) the server SHOULD return one ticket.

Servers SHOULD additionally place a limit on the number of tickets they are
willing to send, to save resources.  Therefore, the number of NewSessionTicket
messages sent will typically be the minimum of the server's self-imposed limit
and the number requested.

A server that supports ticket requests MAY echo the "ticket_request" extension
in the EncryptedExtensions message. If present, it contains a
TicketRequestContents structure, where TicketRequestContents.new_session_count
indicates the number of tickets the server expects to send to the client.

If the extension is echoed, the TicketRequestContents.resumption_count can
be set to a non-zero value to indicate that the server supports ticket
reuse, otherwise (i.e. zero) the server does not support ticket reuse.  Ticket
reuse has privacy implications and should be used with care or not at all,
see the security considerations section.

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
server Finished message (see {{RFC8446}}; Section 4.6.1). A server which chooses to send a large number of tickets to a client
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
this draft.
