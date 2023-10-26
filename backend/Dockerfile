FROM devbfvio/openedge-pas:12.7-dev

COPY PUGWebHandler.cls /app/src/
COPY as.pf /app/pas/as.pf

RUN bin/oeprop.sh +pas.ROOT.WEB.handler1=PUGWebHandler:/

EXPOSE 8810

CMD [ "bash", "-C", "/app/pas/start.sh" ]
