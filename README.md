# This Repository is Archived

This Repository is now read-only, and will not be accepting Issues or PRs.
The official Apache Solr Docker image is now managed in the following places:

- For all continuing feature-work, the `9.x` and further Solr images are managed in the [Apache Solr repository](https://github.com/apache/solr). \
  Please follow the [community guidelines](https://solr.apache.org/community.html) for asking question, contributing and raising issues.
- As of now, the Solr `8.11.y` line is still supported for security fixes. These images are not maintained in the Solr repository, but instead in the [Solr Docker repository](https://github.com/apache/solr-docker). \
  This repository is meant to be a means to store already released Dockerfiles for the Docker Official Images team, but will also be the host for the `8.11.z` Solr image until it is no-longer supported (when Solr 10.0 is released). \
  You can raise issues and ask questions the same way, following the [community guidelines](https://solr.apache.org/community.html).

Please do not raise issues for CVEs found in dependencies in the base docker image. The Official Docker images team handles upgrades of the base images, and we do not have control over that process. For CVEs found in the Solr dependency libraries, please take the [Solr Security Wiki](https://cwiki.apache.org/confluence/display/SOLR/SolrSecurity#SolrSecurity-SolrandVulnerabilityScanningTools) into consideration before raising an issue or sending a message to the Security mailing-list.

For those looking for Log4J 2 "Log4shell" information, please read [Solr's security bulletin](https://solr.apache.org/security.html#apache-solr-affected-by-apache-log4j-cve-2021-44228).

# License

Solr is licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).

This repository is licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).

Copyright 2015-2020 The Apache Software Foundation

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

# History

This project was started in 2015 by [Martijn Koster](https://github.com/makuk66). In 2019 maintainership and copyright was transferred to the Apache Lucene/Solr project. Many thanks to Martijn for all your contributions over the years!
