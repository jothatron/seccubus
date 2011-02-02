# ------------------------------------------------------------------------------
# $Id$
# ------------------------------------------------------------------------------
# Seccubus perl module. This is where most of the real logic is
# ------------------------------------------------------------------------------
#  Copyright 2011 Frank Breedijk of Schuberg Philis
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
# ------------------------------------------------------------------------------
package SeccubusWorkspaces;

=head1 NAME $RCSfile: SeccubusWorkspaces.pm,v $

This Pod documentation generated from the module SeccubusWorkspaces gives a 
list of all functions within the module.

=cut

use Exporter;

@ISA = ('Exporter');

@EXPORT = qw ( 
		create_workspace
		delete_workspace
		edit_workspace
		get_workspaces
		get_workspace_id
	);

use strict;
use Carp;

use SeccubusDB;
use SeccubusRights;

sub create_workspace($;);
sub delete_workspace($;$);
sub edit_workspace($$;);
sub get_workspaces(;);
sub get_workspace_id($;);

=head1 Data manipulation - Workspaces

=head2 create_workspace

Creates a new workspace in the database or return 0 if workspace allready exists

=over 2

=item Parameters

=over 4

=item name - Workspace name

=back 

=item Checks

User must be an admin. A workspace with this name musn't exist.

=back 

=cut 

sub create_workspace($;) {
	my $name = shift;
	my $id;

	confess "No workspace name provided" unless $name;
	confess "You need to be an administrator to use this function" unless is_admin();

	my $count = sql( "return"	=> "array",
			 "query"	=> "SELECT count(*) from workspaces where name = ?",
			 "values"	=> [ $name ]
		       );
	
	if ( $count ) {
		return 0;
	} else {
		$id = sql( "return"	=> "id",
			   "query"	=> "INSERT into workspaces(name) values (?)",
			   "values"	=> [ $name ]
			 );
		return $id;
	}
}

=head1 Data manipulation - Workspaces

=head2 delete_workspace

Deletes a workspace from the database or return 0 if fails

=over 2

=item Parameters

=over 4

=item name - Workspace name

=item verbose (optional) - If verbose is set, progress will be printed to STDOUT

=back 

=item Checks

User must be an admin. The workspace name must exist in the database.

=back 

=cut 

sub delete_workspace($;$) {
	my $name = shift;
	my $verbose = shift;

	confess "No workspace name provided" unless $name;
	confess "You need to be an administrator to use this function" unless is_admin();
	
	# Verify the named passed is a valid workspace name
	my $workspace_id = get_workspace_id($name);
	
	# if the workspace_id is not found exit
	if ($workspace_id == 0) {
		print STDERR "The workspace $name was not found in the database";
		return $workspace_id;
	}
	
	# delete all records in host_names that matches workspace id
	my $rows = sql( "return"	=> "rows",
			 "query"	=> "DELETE FROM host_names where workspace_id = ?",
			 "values"	=> [ $workspace_id ]
			 );
	print STDERR "Deleted $rows from host_names table.\n" if $verbose;
	
	# delete all records in rights that matches workspace id
	$rows = sql( "return"	=> "rows",
		 		"query"	=> "DELETE FROM rights WHERE workspace_id = ?",
		 		"values"	=> [ $workspace_id ]
		 		);
	print STDERR "Deleted $rows from rights table.\n" if $verbose;
	
	# For each id in scans that matches workspace id
	my $scans = sql( "return"	=> "ref", 
					"query"	=> "SELECT id FROM scans WHERE workspace_id = ?", 
					"values"	=> [ $workspace_id ],
	       			);
	foreach my $scan_id (@$scans) {
		# delete all records in runs that matches scan_id
		$rows = sql( "return"	=> "rows",
			 "query"	=> "DELETE FROM runs where scan_id = ?",
			 "values"	=> [ $$scan_id[0] ]
			 );
		print STDERR "Deleted $rows from runs table.\n" if $verbose;
	}
	#	delete all records in scans that matches workspace id
	$rows = sql( "return"	=> "rows",
		 "query"	=> "DELETE FROM scans WHERE workspace_id = ?",
		 "values"	=> [ $workspace_id ]
		 );
	print STDERR "Deleted $rows from scans table.\n" if $verbose;

	# For each id in findings that matches workspace id
	my $findings = sql( "return"	=> "ref", 
					   "query"	=> "SELECT id FROM findings WHERE workspace_id = ?", 
					   "values"	=> [ $workspace_id ],
	       			 );
	foreach my $finding_id (@$findings) {
		# delete all records in finding_changes that matches finding_id
		$rows = sql( "return"	=> "rows",
			 		"query"	=> "DELETE FROM finding_changes where finding_id = ?",
			 		"values"	=> [ $$finding_id[0] ]
			 		);
		print STDERR "Deleted $rows from finding_changes table.\n" if $verbose;
		# delete all records in occurances that matches finding_id
		$rows = sql( "return"	=> "rows",
			 		"query"	=> "DELETE FROM occurances where finding_id = ?",
			 		"values"	=> [ $$finding_id[0] ]
			 		);
		print STDERR "Deleted $rows from occurances table.\n" if $verbose;
		# for each unique issue_id in issues2findings that matches finding_id
		my $issues2findings = sql( "return"	=> "ref", 
									"query"	=> "SELECT DISTINCT issue_id FROM issues2findings WHERE finding_id = ?", 
									"values"	=> [ $$finding_id[0] ],
									);
	    foreach my $issue_id (@$issues2findings) {
			# delete all records in issue_changes that matches issue_id
			$rows = sql( "return"	=> "rows",
			 			"query"	=> "DELETE FROM issue_changes where issue_id = ?",
			 			"values"	=> [ $$issue_id[0] ]
			 			);
			print STDERR "Deleted $rows from issue_changes table.\n" if $verbose;
			# delete all records in issue2finding_changes that matches issue_id
			$rows = sql( "return"	=> "rows",
			 			"query"	=> "DELETE FROM issue2finding_changes where issue_id = ?",
			 			"values"	=> [ $$issue_id[0] ]
			 			);
			print STDERR "Deleted $rows from issue2finding_changes table.\n" if $verbose;
			# delete the record in issues that matches issue_id
			$rows = sql( "return"	=> "rows",
			 			"query"	=> "DELETE FROM issue where id = ?",
			 			"values"	=> [ $$issue_id[0] ]
			 			);
			print STDERR "Deleted $rows from issues table.\n" if $verbose;
	    }
		# delete all issues2findings records that matches finding_id
		$rows = sql( "return"	=> "rows", 
					"query"	=> "DELETE FROM issues2findings WHERE finding_id = ?", 
					"values"	=> [ @$finding_id ],
	       			);
	    print STDERR "Deleted $rows from issues2findings table.\n" if $verbose;
	}
	#	delete all findings records that matches workspace id
	$rows = sql( "return"	=> "rows", 
				"query"	=> "DELETE FROM findings WHERE workspace_id = ?", 
				"values"	=> [ $workspace_id ],
				);
	print STDERR "Deleted $rows from findings table.\n" if $verbose;
	
	# Delete the record from the workspaces table that matches workspace id
	$rows = sql( "return"	=> "rows", 
				"query"	=> "DELETE FROM workspaces WHERE id = ?", 
				"values"	=> [ $workspace_id ],
				);
	print STDERR "Deleted $rows from workspaces table.\n" if $verbose;
	
	# Return success
	return 1;
}

=head1 Data manipulation - Workspaces

=head2 edit_workspace

Edits a workspace name in the database or return 0 if workspace already exists

=over 2

=item Parameters

=over 4

=item name - Workspace name to be changed

=item name - New workspace name

=back 

=item Checks

User must be an admin. A workspace with this name musn't exist.

=back 

=cut 

sub edit_workspace($$;) {
	my $name = shift;
	my $newname = shift;

	confess "No workspace name provided" unless $name;
	confess "No new workspace name provided" unless $newname;
	confess "You need to be an administrator to use this function" unless is_admin();

	# Verify the name passed is a valid workspace name and retrieve its' id
	my $id = get_workspace_id($name);
	# if the id is 0 exit
	if ($id == 0) {
		return "notfound";
	}
	
	# Verify the new workspace name does not already exists
	my $count = sql( "return"	=> "array",
			 "query"	=> "SELECT count(*) from workspaces where name = ?",
			 "values"	=> [ $newname ]
		       );
	if ( $count ) {
		return "exists";
	}

	my $rows = sql( "return"	=> "rows",
			"query"	=> "UPDATE workspaces SET name = ? WHERE id = ?",
			"values"	=> [ $newname, $id ]
			 );
	return $rows;
}

=head2 get_workspace_id

Returns the id of a workspace for a given name

=over 2

=item Parameters

=over 4

name - name of the workspace to get the id for

=back 

=item Checks

If the workspace exists the workspace ID is returned, else 0 is returned

=back 

=cut 

sub get_workspace_id($;) {
	my $name = shift; 

	my $id = 
		sql( "return"	=> "array",
		     "query"	=> "SELECT id
		 		    FROM workspaces
				    WHERE name = ?
				    ",
		     "values"	=> [ $name ],
		);
	if ( $id ) {
		return $id;
	} else {
		return 0;
	}
}

=head2 get_workspaces

Returns a reference to a list of workspaces the user can read and/or write
(id, name, scans, lastrun, findings)

=over 2

=item Parameters

=over 4

None

=back 

=item Checks

Only workspaces the user can read and/or write are returned

=back 

=cut 

sub get_workspaces(;) {
	my $workspaces; 
	
	my $user_is_admin = is_admin();

	$workspaces = 
		sql( "return"	=> "ref",
		     "query"	=> "
				   SELECT DISTINCT 
				   	workspaces.id, workspaces.name,
				   	( SELECT MAX(time) FROM scans LEFT JOIN runs ON scans.id = runs.scan_id WHERE scans.workspace_id = workspaces.id) as lastrun,
				   	( SELECT COUNT(*) FROM findings WHERE workspace_id = workspaces.id) as findings,
				   	( SELECT COUNT(*) FROM scans WHERE workspace_id = workspaces.id) as scans
				   FROM workspaces 
				   LEFT JOIN rights ON workspaces.id = rights.workspace_id 
				   LEFT JOIN groups ON rights.group_id = groups.id 
				   LEFT JOIN user2group ON groups.id = user2group.group_id 
				   LEFT JOIN users ON user2group.user_id = users.id
				   WHERE 
				   	(users.username= ? and rights.allow_read=1 or rights.allow_write=1) 
				   OR (1=?);
				   ",
		    "values"	=> [ $ENV{REMOTE_USER}, $user_is_admin ],
	       );
	return $workspaces;
}

# Close the PM file.
return 1;