#!/usr/bin/env bash

# This CGI will be called like so:
#    http://server/$0?id=${execution.id}&status=${execution.status}&trigger=${notification.trigger}

# fixme, should really read up to CONTENT_LENGTH
POST_DATA=$(</dev/stdin)


for VAR in $(echo $QUERY_STRING | tr "&" "\t")
do
  NAME=$(echo $VAR | tr = " " | awk '{print $1}';);
  VALUE=$(echo $VAR | tr = " " | awk '{ print $2}' | tr + " ");
  declare $NAME="$VALUE";
done

dtstamp=$(date +%F%Z%T)

cat > /var/www/html/rundeck/takeovers/$dtstamp.html<<EOF
<html>
<body>
<p>A Takeover occured at $dtstamp</p>
<ul>
<li>execution_id: ${id:-}</li>
<li>status: ${status:-}</li>
<li>trigger: ${trigger:-}</li>
</ul>
<p>Post data</p>
<pre>
$POST_DATA
</pre>
</body>
</html>
EOF

echo Content-type: application/html
echo ""
cat /var/www/html/rundeck/takeovers/$dtstamp.html