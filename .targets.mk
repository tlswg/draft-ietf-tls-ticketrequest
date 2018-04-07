TARGETS_DRAFTS := draft-wood-tls-ticketrequest
TARGETS_TAGS := 
draft-wood-tls-ticketrequest-00.txt: draft-wood-tls-ticketrequest.txt
	sed -e s/draft-wood-tls-ticketrequest-latest/draft-wood-tls-ticketrequest-00/g -e s/draft-wood-tls-ticketrequest-latest/draft-wood-tls-ticketrequest-00/g -e s/draft-wood-tls-ticketrequest-latest/draft-wood-tls-ticketrequest-00/g $< >$@
