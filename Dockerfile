FROM amazonlinux:2
RUN yum install shadow-utils.x86_64 -y
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
RUN python get-pip.py
RUN pip install tweepy
RUN pip install boto3
COPY twitterstream.py .
RUN groupadd -r twitterstream && useradd -r -g twitterstream twitterstream
USER twitterstream
CMD ["python", "-u", "twitterstream.py"]