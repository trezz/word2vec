###############################################################################################
#
# Script for training good word and phrase vector model using public corpora, version 1.0.
# The training time will be from several hours to about a day.
#
# Downloads about 8 billion words, makes phrases using two runs of word2phrase, trains
# a 500-dimensional vector model and evaluates it on word and phrase analogy tasks.
#
###############################################################################################

# This function will convert text to lowercase and remove special characters
normalize_text() {
   awk '{print tolower($0);}' | gsed -e 's/[^a-zA-Z0-9 \n\t\r]//g' -e 's/0-9/ /g'
}

if [ ! -f "news.2012.en.shuffled" ]; then
  wget http://www.statmt.org/wmt14/training-monolingual-news-crawl/news.2012.en.shuffled.gz
  gzip -d news.2012.en.shuffled.gz
fi
if [ ! -f "news.2013.en.shuffled" ]; then
  wget http://www.statmt.org/wmt14/training-monolingual-news-crawl/news.2013.en.shuffled.gz
  gzip -d news.2013.en.shuffled.gz
fi

normalize_text < news.2012.en.shuffled > data.txt
normalize_text < news.2013.en.shuffled >> data.txt

if [ ! -f "1-billion-word-language-modeling-benchmark-r13output.tar.gz" ]; then
  wget http://www.statmt.org/lm-benchmark/1-billion-word-language-modeling-benchmark-r13output.tar.gz
fi
tar -xvf 1-billion-word-language-modeling-benchmark-r13output.tar.gz
for i in `ls 1-billion-word-language-modeling-benchmark-r13output/training-monolingual.tokenized.shuffled`; do
  normalize_text < 1-billion-word-language-modeling-benchmark-r13output/training-monolingual.tokenized.shuffled/$i >> data.txt
done

exit 0

if [ ! -f "enwiki-latest-pages-articles.xml.bz2" ]; then
  wget http://dumps.wikimedia.org/enwiki/latest/enwiki-latest-pages-articles.xml.bz2
fi
bzip2 -c -d enwiki-latest-pages-articles.xml.bz2 | awk '{print tolower($0);}' | perl -e '
# Program to filter Wikipedia XML dumps to "clean" text consisting only of lowercase
# letters (a-z, converted from A-Z), and spaces (never consecutive)...
# All other characters are converted to spaces.  Only text which normally appears.
# in the web browser is displayed.  Tables are removed.  Image captions are.
# preserved.  Links are converted to normal text.  Digits are spelled out.
# *** Modified to not spell digits or throw away non-ASCII characters ***

# Written by Matt Mahoney, June 10, 2006.  This program is released to the public domain.

$/=">";                     # input record separator
while (<>) {
  if (/<text /) {$text=1;}  # remove all but between <text> ... </text>
  if (/#redirect/i) {$text=0;}  # remove #REDIRECT
  if ($text) {

    # Remove any text not normally visible
    if (/<\/text>/) {$text=0;}
    s/<.*>//;               # remove xml tags
    s/&amp;/&/g;            # decode URL encoded chars
    s/&lt;/</g;
    s/&gt;/>/g;
    s/<ref[^<]*<\/ref>//g;  # remove references <ref...> ... </ref>
    s/<[^>]*>//g;           # remove xhtml tags
    s/\[http:[^] ]*/[/g;    # remove normal url, preserve visible text
    s/\|thumb//ig;          # remove images links, preserve caption
    s/\|left//ig;
    s/\|right//ig;
    s/\|\d+px//ig;
    s/\[\[image:[^\[\]]*\|//ig;
    s/\[\[category:([^|\]]*)[^]]*\]\]/[[$1]]/ig;  # show categories without markup
    s/\[\[[a-z\-]*:[^\]]*\]\]//g;  # remove links to other languages
    s/\[\[[^\|\]]*\|/[[/g;  # remove wiki url, preserve visible text
    s/{{[^}]*}}//g;         # remove {{icons}} and {tables}
    s/{[^}]*}//g;
    s/\[//g;                # remove [ and ]
    s/\]//g;
    s/&[^;]*;/ /g;          # remove URL encoded chars

    $_=" $_ ";
    chop;
    print $_;
  }
}
' | normalize_text | awk '{if (NF>1) print;}' >> data.txt

./word2phrase -train data.txt -output data-phrase.txt -threshold 200 -debug 2
./word2phrase -train data-phrase.txt -output data-phrase2.txt -threshold 100 -debug 2
./word2vec -train data-phrase2.txt -output vectors.bin -cbow 1 -size 500 -window 10 -negative 10 -hs 0 -sample 1e-5 -threads 40 -binary 1 -iter 3 -min-count 10
./compute-accuracy vectors.bin 400000 < questions-words.txt     # should get to almost 78% accuracy on 99.7% of questions
./compute-accuracy vectors.bin 1000000 < questions-phrases.txt  # about 78% accuracy with 77% coverage
