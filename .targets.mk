TARGETS_DRAFTS := draft-wood-tls-ticketrequest
TARGETS_TAGS := 
draft-wood-tls-ticketrequest-00.md: draft-wood-tls-ticketrequest.md
	sed -e s/draft-wood-tls-ticketrequest-latest/draft-wood-tls-ticketrequest-00/g $< >$@
