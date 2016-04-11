FROM        perl:latest
MAINTAINER  Fernando Correa de Oliveira <fco@cpan.org>

RUN curl -L http://cpanmin.us | perl - App::cpanminus
RUN cpanm Carton Starman

COPY cpanfile /workdir/cpanfile
COPY entrypoint.sh /workdir/entrypoint.sh
RUN cd /workdir && carton

EXPOSE 3000

WORKDIR /workdir

ENTRYPOINT ["/workdir/entrypoint.sh"]
CMD ["perl test.pl", "daemon"]
