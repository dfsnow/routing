FROM debian:jessie

ENV OTP_VERSION 1.3.0
ENV JYTHON_VERSION 2.7.1

ENV AWS_DEFAULT_REGION=$aws_default_region \
    AWS_ACCESS_KEY=$aws_access_key \
    AWS_SECRET_ACCESS_KEY=$aws_secret_access_key

RUN \
    #echo "===> add webupd8 repository..."  && \
    #echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" | tee /etc/apt/sources.list.d/webupd8team-java.list  && \
    #echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" | tee -a /etc/apt/sources.list.d/webupd8team-java.list  && \
    #apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886  && \
    echo "deb http://repos.azulsystems.com/debian stable main" | tee /etc/apt/sources.list.d/zulu.list && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0xB1998361219BD9C9 && \
    apt-get update  && \
    apt-get install -y wget s3cmd software-properties-common && \
    apt install -y zulu-8 && \
    \
    \
    echo "===> install Java"  && \
    #echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections  && \
    #echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections  && \
    #DEBIAN_FRONTEND=noninteractive  apt-get install -y --force-yes oracle-java8-installer oracle-java8-set-default  && \
    \
    \
    echo "===> clean up..."  && \
    rm -rf /var/cache/oracle-jdk8-installer  && \
    apt-get clean  && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir /otp/ /otp/graphs && \
wget https://repo1.maven.org/maven2/org/python/jython-standalone/$JYTHON_VERSION/jython-standalone-$JYTHON_VERSION.jar \
-O /otp/jython-standalone-$JYTHON_VERSION.jar && \
wget https://repo1.maven.org/maven2/org/opentripplanner/otp/$OTP_VERSION/otp-$OTP_VERSION-shaded.jar -O /otp/otp-$OTP_VERSION-shaded.jar

COPY create_otp_matrix.py run_otp.sh /otp/
RUN chmod +x /otp/run_otp.sh

CMD ["/bin/bash", "-c", "/otp/run_otp.sh"] 

