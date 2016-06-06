require 'date'
require 'gooddata'
require 'csv'
require 'optparse'
require 'yaml'

# get all options for user input
options = {}
OptionParser.new do |opts|

  opts.on('-u', '--username USER', 'Username') { |v| options[:username] = v }
  opts.on('-p', '--password PASS', 'Password') { |v| options[:password] = v }
  opts.on('-m', '--masterproject NAME', 'Master Project') { |v| options[:master] = v }
  opts.on('-d', '--releasedate DATE', 'Release Date') { |v| options[:date] = v }
  opts.on('-h', '--hostname NAME', 'Hostname') { |v| options[:server] = v }
  opts.on('-i', '--include INCLUDE', 'Tag included') { |v| options[:incl] = v }
  opts.on('-e', '--exclude EXCLUDE', 'Tag excluded') { |v| options[:excl] = v }

end.parse!

# assign credentials from user input
username = options[:username]
password = options[:password]
server = options[:server]
incl = options[:incl]
excl = options[:excl]

# make arrays from incl and excl parameters
if incl.to_s != ''
  incl = incl.split(",")
end

if excl.to_s != ''
  excl = excl.split(",")
end

# variables for script results
result_array = []
$result = []
counter_ok = 0
counter_err = 0


# if not whitelabeled set to default domain
if server.to_s.empty? then
  server = 'https://secure.gooddata.com'
end

# turn off GoodData logging
GoodData.logging_off

# set date from which we will check unfinished objects
last_release_date = Time.strptime(options[:date], '%Y-%m-%d')

# assign master project to variable
master = options[:master]


# connect to GoodData and check all objects for specific setup
GoodData.with_connection(login: username, password: password, server: server) do |client|

  GoodData.with_project(master) do |project|


    #-----------------------------DASHBOARDS------------------------------------
    dashboards_to_migrate = project.dashboards.select { |dashboard| dashboard.updated > last_release_date }
    dashboards_to_migrate = dashboards_to_migrate.select { |dashboard| incl.to_s == '' || !(dashboard.tag_set & incl).empty? }.sort_by(&:title)
    dashboards_to_migrate = dashboards_to_migrate.select { |dashboard| excl.to_s == '' || (dashboard.tag_set & excl).empty? }.sort_by(&:title)

    # print all dashboards with unfinished setup
    dashboards_to_migrate.each do |dashboard|
      if !(dashboard.locked?) then
        unlocked = ' | UNLOCKED!'
      else
        unlocked = ''
      end
      if (dashboard.summary == '') then
        missing_desc = ' | MISSING DESCRIPTION'
      else
        missing_desc = ''
      end
      if (dashboard.meta['unlisted'] == 1) then
        unlisted = ' | UNLISTED!'
      else
        unlisted = ''
      end
      if (unlocked != '' || missing_desc != '' || unlisted != '')
      then
        counter_err += 1
        result_array.push(error_details = {
            :type => "ERROR",
            :url => server + '#s=/gdc/projects/' + master + '|projectDashboardPage|' + dashboard.uri,
            :api => server + dashboard.uri,
            :title => dashboard.title,
            :description => 'The dashboard ('+ dashboard.title + ') - errors: ' + unlocked + missing_desc + unlisted
        })
      else
        counter_ok += 1
      end
    end
    #save errors in the result variable
    $result.push({:section => 'Unfinished dashboards.', :OK => counter_ok, :ERROR => counter_err, :output => result_array})
    #reset result variables
    result_array = []
    counter_ok = 0
    counter_err = 0

    #-----------------------------REPORTS-----------------------------------
    reports_to_migrate = project.reports.select { |report| report.updated > last_release_date }
    reports_to_migrate = reports_to_migrate.select { |report| incl.to_s == '' || !(report.tag_set & incl).empty? }.sort_by(&:title)
    reports_to_migrate = reports_to_migrate.select { |report| excl.to_s == '' || (report.tag_set & excl).empty? }.sort_by(&:title)

    # print all reports with unfinished setup
    reports_to_migrate.each do |report|
      if !(report.locked?) then
        unlocked = ' | UNLOCKED!'
      else
        unlocked = ''
      end
      if (report.summary == '') then
        missing_desc = ' | MISSING DESCRIPTION'
      else
        missing_desc = ''
      end
      if (report.meta['unlisted'] == 1) then
        unlisted = ' | UNLISTED!'
      else
        unlisted = ''
      end
      if (unlocked != '' || missing_desc != '' || unlisted != '')
      then
        counter_err += 1
        result_array.push(error_details = {
            :type => "ERROR",
            :url => server + '#s=/gdc/projects/' + master + '|analysisPage|head|' + report.uri,
            :api => server + report.uri,
            :title => report.title,
            :description => 'The report ('+ report.title + ') - errors: ' + unlocked + missing_desc + unlisted
        })
      else
        counter_ok += 1

      end
    end
    #save errors in the result variable
    $result.push({:section => 'Unfinished reports.', :OK => counter_ok, :ERROR => counter_err, :output => result_array})
    #reset result variables
    result_array = []
    counter_ok = 0
    counter_err = 0

    #-----------------------------METRICS-----------------------------------
    metrics_to_migrate = project.metrics.select { |metric| metric.updated > last_release_date }
    metrics_to_migrate = metrics_to_migrate.select { |metric| incl.to_s == '' || !(metric.tag_set & incl).empty? }.sort_by(&:title)
    metrics_to_migrate = metrics_to_migrate.select { |metric| excl.to_s == '' || (metric.tag_set & excl).empty? }.sort_by(&:title)

    # print all metrics with unfinished setup
    metrics_to_migrate.each do |metric|
      if !(metric.locked?) then
        unlocked = ' | UNLOCKED!'
      else
        unlocked = ''
      end
      if (metric.summary == '') then
        missing_desc = ' | MISSING DESCRIPTION'
      else
        missing_desc = ''
      end
      if (metric.meta['unlisted'] == 1) then
        unlisted = ' | UNLISTED!'
      else
        unlisted = ''
      end
      if (unlocked != '' || missing_desc != '' || unlisted != '')
      then
        counter_err += 1
        result_array.push(error_details = {
            :type => "ERROR",
            :url => server + '#s=/gdc/projects/' + master + '|objectPage|' + metric.uri,
            :api => server + metric.uri,
            :title => metric.title,
            :description => 'The metric ('+ metric.title + ') - errors: ' + unlocked + missing_desc + unlisted
        })
      else
        counter_ok += 1
      end
    end
    #save errors in the result variable
    $result.push({:section => 'Unfinished metrics.', :OK => counter_ok, :ERROR => counter_err, :output => result_array})


  end
end
#print out the result
puts $result.to_json

GoodData.disconnect
