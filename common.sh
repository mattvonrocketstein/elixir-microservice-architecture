if [ -z "$COOKIE" ]; then echo "\$COOKIE is not set!" && exit 1; else echo "Found cookie.."; fi
ip=`ip a | grep global | grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])'`
str=`date -Ins | md5sum`
name=node${str:0:3}
node="${name}@${ip}"
echo "Node name: $node"

