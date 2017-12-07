---
title: Short-Lived Key Shares
abbrev: Short-Lived Key Shares
docname: draft-wood-tls-shortlivedshare-latest
date:
category: info

ipr: trust200902
keyword: Internet-Draft

stand_alone: yes
pi: [toc, sortrefs, symrefs]

author:
 -
    ins: N. Sullivan
    name: Nick Sullivan
    org: Cloudflare
    street: 101 Townsend St
    city: San Francisco
    country: United States of America
    email: nick@cloudflare.com
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

--- abstract

XXX

--- middle

# Introduction



XXX

A XXX is a digitally signed data structure with the
following semantic fields:

- A validity interval
- XXX
- A public key (with its associated algorithm)

## Use Cases

Q: why use a key share instead of previously-established PSK?
- XXX

XXX
- Client EncryptedExtensions for resumed sessions
- 

~~~
Client            Front-End            Back-End
     |----ClientHello--->|                    |
     |<---ServerHello----|                    |
     |<---Certificate----|                    |
     |                   |<-------LURK------->|
     |<---CertVerify-----|                    |
     |        ...        |                    |
~~~


# Short Lived Shares

This document defines the following extension code point.

~~~
enum {
    ...
    short_lived_share(TBD),
    (65535)
} ExtensionType;
~~~

XXX

~~~
struct {
    NamedGroup group;
    opaque key_exchange<1..2^16-1>;
} KeyShareEntry;

struct {
    KeyShareEntry key_share_list<2..2^16-1>;
    uint32 validTime;
    SignatureScheme scheme;
    opaque signature<0..2^16-1>;
} ShortLivedShare;
~~~

validTime:  Relative time in seconds from the beginning of the
certificate's notBefore value after which the Delegated Credential
is no longer valid.

publicKey: The Delegated Credential's public key which is an encoded
SubjectPublicKeyInfo [RFC5280].

scheme: The Signature algorithm and scheme used to sign the
Delegated credential.

signature: The signature over the credential with the end-entity
certificate's public key, using the scheme.

# IANA Considerations

XXX

# Security Considerations

XXX

# Acknowledgments

XXX
