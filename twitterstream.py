from __future__ import absolute_import, print_function

from tweepy.streaming import StreamListener
from tweepy import OAuthHandler
from tweepy import Stream
import json
import boto3
import os

# DynamoDB Table name and Region
dynamoDBTable=os.environ['DYNAMODBTABLE']
region_name=os.environ['AWSREGION']

# Filter variable (the word you want to filter in your stream)
filter=os.environ['FILTER']

# Go to http://apps.twitter.com and create an app.
# The consumer key and secret will be generated for you after
consumer_key=os.environ['CONSUMERKEY']
consumer_secret=os.environ['CONSUMERSECRETKEY']

# After the step above, you will be redirected to your app's page.
# Create an access token under the "Your access token" section
access_token=os.environ['ACCESSTOKEN']
access_token_secret=os.environ['ACCESSTOKENSECRET']

class StdOutListener(StreamListener):
    """ A listener handles tweets that are received from the stream.
    This is a basic listener that just prints received tweets to stdout.
    """
    def on_data(self, data):
        j = json.loads(data)
        tweetuser = j['user']['screen_name']
        tweetdate = j['created_at']
        tweettext = j['text'].encode('ascii', 'ignore').decode('ascii')
        print(tweetuser)
        print(tweetdate)
        print(tweettext)
        dynamodb = boto3.client('dynamodb',region_name)
        dynamodb.put_item(TableName=dynamoDBTable, Item={'user':{'S':tweetuser},'date':{'S':tweetdate},'text':{'S':tweettext}})
        return True

    def on_error(self, status):
        print(status)

if __name__ == '__main__':
    l = StdOutListener()
    auth = OAuthHandler(consumer_key, consumer_secret)
    auth.set_access_token(access_token, access_token_secret)

    stream = Stream(auth, l)
stream.filter(track=[filter])