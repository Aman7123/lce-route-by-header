McAfee AWS Kinesis
====================
* Experimental code in `develop` branch
* Prerequisites: Lua knowledge / experience

This repository contains a custom modification of [AWS Kinesis Kong Plugin](https://github.com/rbang1/kong-plugin-aws-kinesis) for McAfee. This plugin accepts AWS Kinesis logs on a Kong route and forwards this traffic through a TCP connection to AWS Kinesis data steam. This specific plugin was designed to consume a wider range of request bodies including batched if selected and `data_template`.

Configuration
=================================
 * aws_key - (required) Aws Access Key
 * aws_secret - (required) Aws Secret Key
 * aws_region - (required) Aws Region
 * stream_name - (required) Kinesis Stream Name
 * data_template - Json template for generating json data to be posted to Kinesis 
 * timeout - Connection timeout in ms, default 60000
 * keepalive - Connection keepalive in ms, default 60000
 * aws_debug - Debug flag, default false

Installation
=================================
Please review [plugin distribution](https://docs.konghq.com/gateway/latest/plugin-development/distribution/)

Testing
=================================
This template was designed to work with the
[`kong-pongo`](https://github.com/Kong/kong-pongo) and
[`kong-vagrant`](https://github.com/Kong/kong-vagrant) development environments.

To test please install one framework above and run `pongo run` in the default repo

Example resources
=================================
* For a complete walkthrough of Kong plugin creation check [this blogpost on the Kong website](https://konghq.com/blog/custom-lua-plugin-kong-gateway).
* For Kong PDK resources see [Kong docs](https://docs.konghq.com/gateway/latest/pdk/)