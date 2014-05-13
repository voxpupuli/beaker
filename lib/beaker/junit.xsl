<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:output method="html" indent="yes"/>
<xsl:decimal-format decimal-separator="." grouping-separator="," />

<xsl:template match="testsuites">
  <html>
  <head>
    <meta charset="utf-8"/>
    <meta http-equiv="X-UA-Compatible" content="IE=edge"/>
    <meta name="viewport" content="width=device-width, initial-scale=1"/>
    <link href="http://maxcdn.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css" rel="stylesheet"/>
  </head>

  <body>
    <!-- jQuery 2.1.1 -->
    <script src="http://ajax.googleapis.com/ajax/libs/jquery/2.1.1/jquery.min.js"></script>
    <!-- Latest compiled and minified JavaScript -->
    <script src="http://maxcdn.bootstrapcdn.com/bootstrap/3.1.1/js/bootstrap.min.js"></script>


    <xsl:variable name="time_format"><xsl:value-of select="'#0.00000'"/></xsl:variable>

    <div class="container-fluid">
      <div class="page-header">
        <h1>Beaker <small>Puppet Labs Automated Acceptance Testing System</small></h1>
      </div>

      <!-- calculate overall stats for this run -->
      <xsl:variable name="total_tests"><xsl:value-of select="sum(testsuite/@tests)"/></xsl:variable>
      <xsl:variable name="total_errors"><xsl:value-of select="sum(testsuite/@errors)"/></xsl:variable>
      <xsl:variable name="total_failures"><xsl:value-of select="sum(testsuite/@failures)"/></xsl:variable>
      <xsl:variable name="total_time"><xsl:value-of select="sum(testsuite/@time)"/></xsl:variable>
      <xsl:variable name="total_skip"><xsl:value-of select="sum(testsuite/@skip)"/></xsl:variable>
      <xsl:variable name="total_pending"><xsl:value-of select="sum(testsuite/@pending)"/></xsl:variable>

      <!-- determine if we overall passed or failed -->
      <xsl:variable name="total_panel_type">
        <xsl:choose>
          <xsl:when test="$total_errors > 0 or $total_failures > 0">danger</xsl:when>
          <xsl:otherwise>success</xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <!-- create the overall panel with stats, colored correctly based upon results -->
      <div class="panel panel-{$total_panel_type}">
        <div class="panel-heading">
          <div class="panel-title">
            <div class="row">
              <div class="col-md-4">
                <h2>Elapsed Time: <xsl:value-of select="format-number($total_time, $time_format)"/> sec </h2>
              </div>
            </div>
            <div class="row">
              <div class="col-md-4">
              </div>
              <div class="col-md-2">
                <h2>Total: <xsl:value-of select="$total_tests" /> </h2>
              </div>
              <div class="col-md-2">
                <h2>Failed: <xsl:value-of select="$total_errors + $total_failures" /></h2>
              </div>
              <div class="col-md-2">
                <h2>Skipped: <xsl:value-of select="$total_skip" /> </h2>
              </div>
              <div class="col-md-2">
                <h2>Pending: <xsl:value-of select="$total_pending" /> </h2>
              </div>
            </div> <!-- row -->
          </div> <!-- panel-title -->
        </div> <!--panel-heading -->

      <div class="panel-body">
        <div class="panel-group" id="accordion_one">
          <xsl:for-each select="testsuite">
          <!-- let's loop over the availables test suites -->
            <xsl:variable name="testsuite_name"><xsl:value-of select="@name"/></xsl:variable>

            <xsl:variable name="testsuite_name_safe" select="translate($testsuite_name,'.','_')" />
            <xsl:variable name="testsuite_tests"><xsl:value-of select="@tests"/></xsl:variable>
            <xsl:variable name="testsuite_errors"><xsl:value-of select="@errors"/></xsl:variable>
            <xsl:variable name="testsuite_failures"><xsl:value-of select="@failures"/></xsl:variable>
            <xsl:variable name="testsuite_time"><xsl:value-of select="@time"/></xsl:variable>
            <xsl:variable name="testsuite_skip"><xsl:value-of select="@skip"/></xsl:variable>
            <xsl:variable name="testsuite_pending"><xsl:value-of select="@pending"/></xsl:variable>
            <xsl:variable name="testsuite_panel_type">
              <xsl:choose>
                <xsl:when test="$testsuite_errors > 0 or $testsuite_failures > 0">danger</xsl:when>
                <xsl:otherwise>success</xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
            <div class="panel panel-{$testsuite_panel_type}">
              <div class="panel-heading">
                <div class="panel-title">
                  <a data-toggle="collapse" data-parent="#accordion_one" href="#{$testsuite_name_safe}">
                    <div class="row">
                      <div class="col-md-2">
                        <h4><xsl:value-of select="$testsuite_name" /></h4>
                      </div>
                      <div class="col-md-4">
                        <h4>Elapsed Time: <xsl:value-of select="format-number($testsuite_time, $time_format)"/> sec</h4>
                      </div>
                    </div>
                    <div class="row">
                      <div class="col-md-2">
                      </div>
                      <div class="col-md-2">
                        <h4>Total: <xsl:value-of select="$testsuite_tests" /></h4>
                      </div>
                      <div class="col-md-2">
                        <h4>Failed: <xsl:value-of select="$testsuite_errors + $testsuite_failures" /></h4>
                      </div>
                      <div class="col-md-2">
                        <h4>Skipped: <xsl:value-of select="$testsuite_skip" /></h4>
                      </div>
                      <div class="col-md-2">
                        <h4>Pending: <xsl:value-of select="$testsuite_pending" /></h4>
                      </div>
                    </div> <!-- row -->
                  </a>
                </div> <!-- panel-title -->
              </div> <!-- panel-heading -->
              <div id="{$testsuite_name_safe}" class="panel-collapse collapse">
                <div class="panel-body">
                  <div class="panel-group" id="accordion_two">
                    <div class="panel panel-primary">
                      <div class="panel-heading">
                        <h5 class="panel-title">
                          <a data-toggle="collapse" data-parent="#accordion_two" href="#{$testsuite_name_safe}-properties">
                            <div class="row">
                              <div class="col-md-4">
                                Properties
                              </div>
                              <div class="col-md-4">
                              </div>
                            </div> <!-- row -->
                          </a>
                        </h5> <!-- panel-title -->
                      </div> <!-- panel-heading -->
                      <div id="{$testsuite_name_safe}-properties" class="panel-collapse collapse in">
                        <div class="panel-body" style="height:425px">
                          <div class="panel panel-info" style="overflow-y: auto">
                            <div style="overflow-y:scroll; max-height:400px">
                              <!-- Default panel contents -->
                              <!-- Table -->
                              <table class="table">
                              <xsl:for-each select="properties/property">
                                <xsl:variable name="property_name"><xsl:value-of select="@name"/></xsl:variable>
                                <xsl:variable name="property_value"><xsl:value-of select="@value"/></xsl:variable>
                                <tr>
                                  <td>
                                    <xsl:value-of select="$property_name" />
                                  </td>
                                  <td>
                                    <xsl:value-of select="$property_value" />
                                  </td>
                                </tr>
                              </xsl:for-each>
                              </table>
                            </div> <!-- overflow div -->
                          </div> <!-- panel panel-info -->
                        </div> <!-- panel-body -->
                      </div> <!-- panel-collapse collapse -->
                    </div> <!-- panel panel-info -->
                  <!-- Start: Here are the test cases for a given test suite -->
                  <xsl:for-each select="testcase">
                    <xsl:variable name="testcase_name"><xsl:value-of select="@name"/></xsl:variable>
                    <xsl:variable name="testcase_classname"><xsl:value-of select="@classname"/></xsl:variable>
                    <xsl:variable name="testcase_fullpath"><xsl:value-of select="concat($testcase_classname, '/', $testcase_name)"/></xsl:variable>
                    <xsl:variable name="testcase_time"><xsl:value-of select="@time"/></xsl:variable>
                    <xsl:variable name="testcase_link" select="translate(translate($testcase_fullpath, '/', '_'), '.', '_')" />
                    <xsl:variable name="testcase_panel_type">
                      <xsl:choose>
                        <xsl:when test="failure or error">danger</xsl:when>
                        <xsl:when test="skip">warning</xsl:when>
                        <xsl:when test="pending">info</xsl:when>
                        <xsl:otherwise>success</xsl:otherwise>
                      </xsl:choose>
                    </xsl:variable>
                    <div class="panel panel-{$testcase_panel_type}">
                      <div class="panel-heading">
                        <div class="panel-title">
                          <a data-toggle="collapse" data-parent="#accordion_two" href="#{$testcase_link}">
                            <div class="row">
                              <div class="col-md-7">
                                <h5><xsl:value-of select="$testcase_name" /></h5>
                              </div>
                            </div>
                            <div class="row">
                              <div class="col-md-1">
                              </div>
                              <div class="col-md-7">
                                <h5>Path: <xsl:value-of select="$testcase_fullpath" /></h5>
                              </div>
                              <div class="col-md-4">
                                <h5>Elapsed Time: <xsl:value-of select="format-number($testcase_time, $time_format)"/> sec</h5>
                              </div>
                            </div> <!-- row -->
                          </a>
                        </div> <!-- panel-title -->
                      </div> <!-- panel-heading -->
                      <div id="{$testcase_link}" class="panel-collapse collapse in">
                        <div class="panel-body" style="height:425px">
                          <ul class="nav nav-tabs">
                            <li class="active"><a href="#tab1" data-toggle="tab">output</a></li>
                            <xsl:choose>
                              <xsl:when test="system-err and string(system-err)">
                                <li><a href="#tab2" data-toggle="tab">stderr</a></li>
                              </xsl:when>
                              <xsl:otherwise>
                                <li class="disabled"><a href="#tab2">stderr</a></li>
                              </xsl:otherwise>
                            </xsl:choose>
                            <xsl:choose>
                              <xsl:when test="failure">
                                <li><a href="#tab3" data-toggle="tab">failure</a></li>
                              </xsl:when>
                              <xsl:otherwise>
                                <li class="disabled"><a href="#tab3">failure</a></li>
                              </xsl:otherwise>
                            </xsl:choose>
                          </ul>
                          <div class="tab-content">
                            <div class="tab-pane active" id="tab1">
                              <pre class="pre-scrollable">
                                <xsl:value-of select="system-out" />
                              </pre>
                            </div>
                            <div class="tab-pane" id="tab2">
                              <pre class="pre-scrollable">
                                <xsl:value-of select="system-err" />
                              </pre>
                            </div>
                            <div class="tab-pane" id="tab3">
                              <div class="panel panel-default">
                                <div class="panel-heading"><xsl:value-of select="failure/@type" /></div>
                                  <div class="panel-body">
                                    <pre class="pre-scrollable">
                                      <xsl:value-of select="failure/@message" />
                                    </pre>
                                  </div>
                                </div>
                            </div>
                          </div> <!-- tab-content -->
                        </div> <!-- panel-body -->
                      </div> <!-- panel-collapse collapse -->
                    </div> <!-- panel panel-default -->
                  </xsl:for-each>
                  </div>  <!-- panel-group -->
                  <!-- Stop: Here are the test cases for a given test suite -->
                </div> <!-- panel-body -->
              </div> <!-- panel-collapse collapse -->
            </div> <!-- panel panel-default -->
            </xsl:for-each>
          </div> <!-- panel-group -->

        </div> <!-- panel-body -->
      </div> <!-- panel panel -->
    </div> <!-- container -->

  <script type="text/javascript">
    $('.collapse').collapse()
  </script>
  </body>

  </html>


</xsl:template>
</xsl:stylesheet>
