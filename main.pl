#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use JSON;
use Getopt::Long;
use Desktop::Notify;
use File::Copy;

my $DMENU_COMMAND = 'rofi -i -dmenu ';


my $cache_dir = $ENV{XDG_CACHE_HOME} || "/home/$ENV{USER}/.cache";
my $database = "$cache_dir/klimify.db";
my $dbh = DBI->connect("dbi:SQLite:dbname=$database")
    or die "Couldn't connect to database: $DBI::errstr";

sub init_database {
    # Create "projects" table
    my $create_projects_table_query = <<'SQL';
CREATE TABLE IF NOT EXISTS projects (
    id   TEXT PRIMARY KEY,
    name TEXT,
    color TEXT,
    archived INTEGER
);
SQL

    $dbh->do($create_projects_table_query) or die "Error creating projects table: $DBI::errstr";

    # Create "tasks" table
    my $create_tasks_table_query = <<'SQL';
CREATE TABLE IF NOT EXISTS tasks (
    id         TEXT PRIMARY KEY,
    project_id TEXT,
    name       TEXT,
    status     TEXT,
    FOREIGN KEY (project_id) REFERENCES projects (id)
);
SQL

    $dbh->do($create_tasks_table_query) or die "Error creating tasks table: $DBI::errstr";

    # Create "history" table
    my $create_history_table_query = <<'SQL';
CREATE TABLE IF NOT EXISTS history (
    id          TEXT PRIMARY KEY,
    description TEXT,
    project_id  TEXT,
    task_id     Text,
    start       DATETIME,

    FOREIGN KEY (project_id) REFERENCES projects (id),
    FOREIGN KEY (task_id) REFERENCES tasks (id)
);
SQL

    $dbh->do($create_history_table_query) or die "Error creating history table: $DBI::errstr";

    my $out_projects = `clockify-cli project list --json`;

# Decode the JSON output
    my $projects = decode_json($out_projects);

# Prepare the SQL statement to insert project data
    my $insert_project_query = <<SQL;
INSERT INTO projects (id, name, color, archived) VALUES (?, ?, ?, ?);
SQL

    my $insert_project = $dbh->prepare($insert_project_query);
    my $insert_task_query = <<SQL;
INSERT INTO tasks (id, name, project_id, status) VALUES (?, ?, ?, ?);
SQL

    my $insert_task = $dbh->prepare($insert_task_query);

    my $check_project_query = <<SQL;
SELECT COUNT(*) FROM projects WHERE id = ?;
SQL

    my $sth_check = $dbh->prepare($check_project_query);

    my $check_task_query = <<SQL;
SELECT COUNT(*) FROM tasks WHERE id = ?;
SQL

    my $sth_check_task = $dbh->prepare($check_task_query);


    # Process the projects
    foreach my $project (@$projects) {
        my $id = $project->{id};
        my $name = $project->{name};
        my $color = $project->{color};
        my $archived = $project->{archived};
        # Access other properties as needed

        print "ID: $id\n";
        print "Name: $name\n";
        print "Color: $color\n";
        print "Archived: $archived\n";


        # Check if project already exists
        $sth_check->execute($id) or die "Error checking project existence: $DBI::errstr";
        my ($count) = $sth_check->fetchrow_array();

        if ($count == 0) {
            # Execute the SQL statement to insert project data
            $insert_project->execute($id, $name, $color, $archived) or die "Error inserting project data: $DBI::errstr";
            print "Project inserted.\n";
        } else {
            print "Project already exists. Skipping insertion.\n";
        }

        my $out_tasks = `clockify-cli task list --project $id --json`;
        # Decode the JSON output
        my $tasks = decode_json($out_tasks);
        foreach my $task (@$tasks) {
            # Check if project already exists
            $sth_check_task->execute($task->{id}) or die "Error checking task existence: $DBI::errstr";
            my ($task_count) = $sth_check_task->fetchrow_array();

            if ($task_count == 0) {
                # Execute the SQL statement to insert project data
                $insert_task->execute($task->{id}, $task->{name}, $id, $task->{status}) or die "Error inserting project data: $DBI::errstr";
                print "Task inserted.\n";
            } else {
                print "Task already exists. Skipping insertion.\n";
            }
        }
    }


## History


    my $out_history = `clockify-cli report 2023-06-01 today --json`;
    # Decode the JSON output
    my $history = decode_json($out_history);

    my $insert_entry_query = <<SQL;
INSERT INTO history (id, description, project_id, task_id, start) VALUES (?, ?, ?, ?, ?);
SQL

    my $insert_entry = $dbh->prepare($insert_entry_query);

    my $check_entry_query = <<SQL;
SELECT COUNT(*) FROM history WHERE id = ?;
SQL

    my $sth_check_entry = $dbh->prepare($check_entry_query);


    foreach my $entry (@$history) {
        $sth_check_entry->execute($entry->{id}) or die "Error checking task existence: $DBI::errstr";
        my ($entry_count) = $sth_check_entry->fetchrow_array();
        print "Entry count = $entry_count\n";

        if ($entry_count == 0) {
            # Execute the SQL statement to insert project data
            $insert_entry->execute($entry->{id}, $entry->{description}, $entry->{project}->{id}, $entry->{task}->{id}, $entry->{timeInterval}->{start}) or die "Error inserting project data: $DBI::errstr";
            print "Entry inserted.\n";
        } else {
            print "Entry already exists. Skipping insertion.\n";
        }
    }






    # Finish the statement handles
    $sth_check->finish;
    $insert_project->finish;
    $sth_check_task->finish;
    $insert_task->finish;
    $sth_check_entry->finish;
    $insert_entry->finish;

    1;
}


sub lookup_project_id {
    my ($project_name) = @_;

    return undef unless defined $project_name;

    my $query = "SELECT id FROM projects WHERE name = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute($project_name);

    my ($project_id) = $sth->fetchrow_array();

    return $project_id;
}

sub lookup_task_id {
    my ($project_id, $task_name) = @_;

    return undef unless defined $project_id && defined $task_name;

    my $query = "SELECT id FROM tasks WHERE project_id = ? AND name = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute($project_id, $task_name);

    my ($task_id) = $sth->fetchrow_array();

    return $task_id;
}


sub get_history {

    my $get_history_query = <<'SQL';
SELECT h.description as name, t.name as task, p.name as project, p.id as pid, t.id as tid
FROM history as h
LEFT JOIN projects p ON h.project_id = p.id
LEFT JOIN tasks t ON h.task_id = t.id
GROUP BY h.description, t.name, p.name
ORDER BY max(start) DESC;
SQL

    my $sth_join = $dbh->prepare($get_history_query);


    $sth_join->execute() or die "Error executing join query: $DBI::errstr";

    my @results = map {
    my $description = $_->{name} // '';
    my $name = $_->{project} // '';
    my $task_name = $_->{task} // '';
    "$description :: $task_name\@$name";
} @{$sth_join->fetchall_arrayref({})};

    my $results_text = join("\n", @results);
    return $results_text;

}
sub get_projects_tasks {

    my $get_project_query = <<'SQL';
SELECT p.name as project, t.name as task FROM projects as p
LEFT JOIN tasks t ON p.id = t.project_id
WHERE p.archived = 0;
SQL

    my $sth_join = $dbh->prepare($get_project_query);


    $sth_join->execute() or die "Error executing join query: $DBI::errstr";

    my @results = map {
    my $name = $_->{project} // '';
    my $task_name = $_->{task} // '[UNDEFINED TASK]';
    "$task_name\@$name";
} @{$sth_join->fetchall_arrayref({})};

    my $results_text = join("\n", @results);
    return $results_text;

}

sub get_projects {
    my $get_project_query = <<'SQL';
SELECT p.name as project  FROM projects as p
WHERE p.archived = 0;
SQL

    my $sth_join = $dbh->prepare($get_project_query);


    $sth_join->execute() or die "Error executing join query: $DBI::errstr";

    my @results = map {
    my $name = $_->{project} // '';
    "$name";
} @{$sth_join->fetchall_arrayref({})};

    my $results_text = join("\n", @results);
    return $results_text;

}


sub select_project_task {
    my $results_text = get_projects_tasks();
    my $project_text = get_projects();

    my $selected_result = `echo -e "\n$project_text\n$results_text" | $DMENU_COMMAND`;
    chomp($selected_result);

    print "Selected Project/task: $selected_result\n";
    return $selected_result

}

sub function_menu() {
    my $result = `echo "Init database\nDANGEROUS: Purge and init\nexit" | $DMENU_COMMAND`;
    chomp($result);
    print("Selected $result\n");
    if ($result eq 'Init database') {
        notify_desktop("INIT DATABASE START (doesn't destroy entries)", "");
        print("Initializing database...\n");
        my $output = init_database();
        notify_desktop("INIT DATABASE FINISH", "$output");
        print("Database initialization finished...\n");
    } elsif ($result eq 'DANGEROUS: Purge and init') {
        # TODO maybe only database purge?
        print("Database purge preparation...\n");
        notify_desktop("Preparing reinit", "database close and MV database");
        print("Database disconnect...\n");
        $dbh->disconnect();
        print("Database move...\n");
        move($database, "$database.old");
        notify_desktop("Reconnecting database", "");
        print("Database reconnect...\n");
        $dbh = DBI->connect("dbi:SQLite:dbname=$database")
            or die "Couldn't connect to database: $DBI::errstr";
        notify_desktop("INIT DATABASE START", "");
        print("Initializing database...\n");
        my $output = init_database();
        notify_desktop("INIT DATABASE FINISH", "$output");
        print("Database initialization finished...\n");

    }

}

sub select_entry {

    my $results_text = get_history();

    # Join the results with newline separator

    # Execute the rofi command and capture the selected result
    my $selected_result = `echo "$results_text" | $DMENU_COMMAND`;
    my $exit_code = $? >> 8;
    chomp($selected_result);


    print("EXIT CODE IS $exit_code\n");
    if ($exit_code == 10) {
        print "Entering function menu 1\n";
        function_menu();
        exit;
    }
    if ($selected_result eq '') {
        print "No output from rofi, exiting...\n";
        exit;
    }

    print "Selected Result: $selected_result\n";
    my ($description, $task_name, $project_name) = $selected_result =~ /(.*) :: (.*)@(.*)/;

    if (!defined $project_name) {
        my $project_task = select_project_task();
        ($task_name, $project_name) = $project_task =~ /(.*)@(.*)/;
        $description = $selected_result;
        print "Description: $description, TASK: $task_name, PROJECT: $project_name\n";
    }
    print($project_name);


    $project_name =~ s/^\s+|\s+$//g;  # Trim leading and trailing spaces
    $task_name =~ s/^\s+|\s+$//g;  # Trim leading and trailing spaces

    print "Project Name: $project_name\n";
    print "Task Name: $task_name\n";

    # # Look up project ID and task ID based on names
    my $project_id = lookup_project_id($project_name);
    my $task_id = lookup_task_id($project_id, $task_name);

    if (!defined $task_id) {
        print "No task ID, probably doesn't exist\n";
        $task_id = create_task($task_name, $project_name);
        if(length $task_id == 0) {
            print STDERR "Could not create task but no task selected\n";
            # TODO: maybe task less project?
            exit 1;

        }

    }
    print "Project ID: $project_id\n";
    print "Task ID: $task_id\n";

    my $result = `clockify-cli start $project_id "$description" --task $task_id --json`;


    my $entry = decode_json($result)->[0];
    if (!defined $entry) {
        # TODO: error message
    }

    my $insert_entry_query = <<SQL;
INSERT INTO history (id, description, project_id, task_id, start) VALUES (?, ?, ?, ?, ?);
SQL

    my $insert_entry = $dbh->prepare($insert_entry_query);

    $insert_entry->execute($entry->{id},
                           $entry->{description},
                           $entry->{project}->{id},
                           $entry->{task}->{id},
                           $entry->{timeInterval}->{start}) or die "Error inserting project data: $DBI::errstr";

    notify_desktop("start $description", "$task_name\@$project_name");




}

sub ask_create_task {
    my $task_name = shift @_;
    my $project_name = shift @_;


    my $selected_result = `echo "YES\nNO\n" | $DMENU_COMMAND -p "Create new task \"$task_name\"\\@$project_name? "`;
    chomp($selected_result);
    if ($selected_result eq '') {
        print "No output from rofi, exiting...\n";
        exit;
    }
    if ($selected_result eq 'YES') {
        return 1;
    }
    return 0;
}

sub create_task {
    my $task_name = shift @_;
    my $project_name = shift @_;
    my $project_id = shift @_;

    if (ask_create_task($task_name, $project_name)) {
        my $result = `clockify-cli task add -p "$project_name" --name "$task_name" --json`;
        print "Created new task $task_name\n";
        # TODO: validation
        my $task = decode_json($result)->[0];
        my $insert_task_query = <<SQL;
INSERT INTO tasks (id, name, project_id, status) VALUES (?, ?, ?, ?);
SQL

        my $insert_task = $dbh->prepare($insert_task_query);
        $insert_task->execute($task->{id}, $task->{name}, $task->{projectId}, $task->{status}) or die "Error inserting project data: $DBI::errstr";
        return $task->{id};
    }
    return "";

}

sub clockify_stop {
    my $result = `clockify-cli out --json`;
    my $entry = decode_json($result)->[0];

    my $description = $entry->{description};
    my $task_name = $entry->{task}->{name} || '';
    my $project_name = $entry->{project}->{name};
    notify_desktop("out $description", "$task_name\@$project_name");
}

# init_database();
# get_history();
# select_entry();





# Define variables
my $help;

# Parse command-line options
GetOptions(
    'help' => \$help
);

# Handle the --help option
if ($help) {
    usage();
    exit;
}

# Get the command argument
my $command = shift @ARGV;

# Handle the command and perform the corresponding actions
if ($command) {
    if ($command eq 'init') {
        init_database();
        exit;
    }
    elsif ($command eq 'start-dmenu' || $command eq 'start') {
        select_entry();
    }
    elsif ($command eq 'stop') {
        clockify_stop();
    }
    else {
        print "Unknown command: $command\n";
        exit;
    }
}
else {
    print "Please provide a command.\n";
    usage();
    exit;
}

# Function to display usage information
sub usage {
    print "Usage: $0 [init|start|start-dmenu]\n";
    print "Commands:\n";
    print "  init\t\tPerform database initialization\n";
    print "  start|start-dmenu\t\tSelect and start-dmenu clockify entry\n";
    print "  stop\t\tStop current entry with clockify-cli out\n";
}

sub notify_desktop {
    my $summary = shift @_;
    my $text = shift @_;
    
    my $notify = Desktop::Notify->new();
    my $notification = $notify->create(summary => "Klimify: $summary",
                            body => "$text",
                            timeout => 2000
        );

    $notification->show();
}










# Disconnect from the database
$dbh->disconnect();

