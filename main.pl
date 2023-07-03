use strict;
use warnings;
use DBI;
use JSON;

my $database = 'database.db';
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
            $sth_check_task->execute($id) or die "Error checking task existence: $DBI::errstr";
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
SELECT COUNT(*) FROM projects WHERE id = ?;
SQL

    my $sth_check_entry = $dbh->prepare($check_entry_query);


    foreach my $entry (@$history) {
        $sth_check_entry->execute($entry->{id}) or die "Error checking task existence: $DBI::errstr";
        my ($entry_count) = $sth_check_entry->fetchrow_array();

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

}


sub lookup_project_id {
    my ($project_name) = @_;

    my $query = "SELECT id FROM projects WHERE name = ?";
    my $sth = $dbh->prepare($query);
    $sth->execute($project_name);

    my ($project_id) = $sth->fetchrow_array();

    return $project_id;
}

sub lookup_task_id {
    my ($project_id, $task_name) = @_;

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
JOIN projects p ON h.project_id = p.id
LEFT JOIN tasks t ON h.task_id = t.id
GROUP BY h.description, t.name, p.name
ORDER BY max(start) DESC;
SQL

    my $sth_join = $dbh->prepare($get_history_query);


    $sth_join->execute() or die "Error executing join query: $DBI::errstr";

    my @results = map {
    my $description = $_->{name} // '[TODO DESCRIPTION]';
    my $name = $_->{project} // '[TODO PROJECT]';
    my $task_name = $_->{task} // '[TODO TASK]';
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

sub select_project_task {
    my $results_text = get_projects_tasks();
    my $rofi_command = 'rofi -dmenu';

    my $selected_result = `echo "$results_text" | $rofi_command`;
    chomp($selected_result);

    print "Selected Result: $selected_result\n";
    return $selected_result

}

sub select_entry {

    my $results_text = get_history();
    my $rofi_command = 'rofi -dmenu';

    # Join the results with newline separator

    # Execute the rofi command and capture the selected result
    my $selected_result = `echo "$results_text" | $rofi_command`;
    chomp($selected_result);

    print "Selected Result: $selected_result\n";
    my ($description, $task_name, $project_name) = $selected_result =~ /(.*) :: (.*)@(.*)/;

    if (!defined $project_name) {
        my $project_task = select_project_task();
        ($task_name, $project_name) = $project_task =~ /(.*)@(.*)/;
        print "TASK: $task_name, PROJECT: $project_name\n";
    }
    print($project_name);


    $project_name =~ s/^\s+|\s+$//g;  # Trim leading and trailing spaces
    $task_name =~ s/^\s+|\s+$//g;  # Trim leading and trailing spaces

    print "Project Name: $project_name\n";
    print "Task Name: $task_name\n";

    # # Look up project ID and task ID based on names
    my $project_id = lookup_project_id($project_name);
    my $task_id = lookup_task_id($project_id, $task_name);

    print "Project ID: $project_id\n";
    print "Task ID: $task_id\n";

    my $result = `clockify-cli start $project_id "$description" --task $task_id --json`;

    print "$result\n";

    my $entry = decode_json($result);

    my $insert_entry_query = <<SQL;
INSERT INTO history (id, description, project_id, task_id, start) VALUES (?, ?, ?, ?, ?);
SQL

    my $insert_entry = $dbh->prepare($insert_entry_query);

    $insert_entry->execute($entry->{id}, $entry->{description}, $entry->{project}->{id}, $entry->{task}->{id}, $entry->{timeInterval}->{start}) or die "Error inserting project data: $DBI::errstr";




}

# init_database();
# get_history();
select_entry();
















# Disconnect from the database
$dbh->disconnect();
