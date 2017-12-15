draft-wood-tls-ticketrequest-00.md: draft-wood-tls-ticketrequest.md
	sed -e s/draft-wood-tls-shortlivedshare-latest/draft-wood-tls-shortlivedshare-00/g -e s/draft-wood-tls-ticketrequest-latest/draft-wood-tls-ticketrequest-00/g $< >$@
