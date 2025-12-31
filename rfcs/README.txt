RFCs formatted in Lex
=====================

This directory contains Internet RFCs converted to Lex format.

Files
-----
- rfc9000.lex: QUIC: A UDP-Based Multiplexed and Secure Transport (Converted from XML)

Conversion Process
------------------
These files are generated using the `lex-cli` tool with the `rfc_xml` format support.
Command: `lex convert --from rfc_xml rfc9000.xml --to lex`
