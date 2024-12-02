version 1.0

workflow update_looker_dashboard {
	input {
		String table_name
		String workspace_name
		String project_name
		String dashboard_data_dir
		String table_data_filename
	}

	call update_dashboard {
		input:
			table_name = table_name,
			project_name = project_name,
			workspace_name = workspace_name,
			dashboard_data_dir = dashboard_data_dir,
			table_data_filename = table_data_filename
	}

	output {
		File table_csv = update_dashboard.table_csv
	}
}

task update_dashboard {
	input{
		String table_name
		String workspace_name
		String project_name
		String dashboard_data_dir
		String table_data_filename
		String drop_entity_name_column = "yes"
		Int page_size = 1000
		String? dashboard_columns
		String docker = "us-docker.pkg.dev/general-theiagen/theiagen/terra-tools:2023-03-16"
		Int memory = 8
		Int cpu = 4
		Int disk_size = 100
	}

	command <<<
		set -euo pipefail

		python3 <<CODE
		from firecloud import api as fapi
		from tqdm import tqdm
		import argparse
		import math

		DEFAULT_PAGE_SIZE = 1000


		def get_entity_by_page(project, workspace, entity_type, page, page_size=DEFAULT_PAGE_SIZE, sort_direction='asc', filter_terms=None):
			# API = https://api.firecloud.org/#!/Entities/entityQuery
			response = fapi.get_entities_query(project, workspace, entity_type, page=page,
											page_size=page_size, sort_direction=sort_direction,
											filter_terms=filter_terms)

			if response.status_code != 200:
				print(response.text)
				exit(1)

			return(response.json())


		def main(project, workspace, entity_type, tsv_name, page_size=DEFAULT_PAGE_SIZE, attr_list=None, drop_entity='yes'):
			# get all entity types in workspace using API call
			# API = https://api.firecloud.org/#!/Entities/getEntityTypes
			response = fapi.list_entity_types(project, workspace)
			if response.status_code != 200:
				print(response.text)
				exit(1)

			# get/report # of entities + associated attributes(column names) of input entity type
			entity_types_json = response.json()
			entity_count = entity_types_json[entity_type]["count"]
			entity_id = entity_types_json[entity_type]["idName"]
			# if user provided list of specific attributes to return, else return all attributes
			if attr_list:
				attr_list = "~{dashboard_columns}".split(",")
				all_attribute_names = entity_types_json[entity_type]["attributeNames"]
				attribute_names = [attr for attr in all_attribute_names if attr in attr_list]
			else:
				attribute_names = entity_types_json[entity_type]["attributeNames"]

			# add the entity_id value to list of attributes (not a default attribute of API response)
			attribute_names.insert(0, entity_id)

			print(f'{entity_count} {entity_type}(s) to export.')

			with open(tsv_name, "w") as tsvout:
				# add header with attribute values to tsv
				tsvout.write(",".join(attribute_names) + "\n")
				# set starting row value and calculate number of pages
				row_num = 0
				num_pages = int(math.ceil(float(entity_count) / page_size))

				# get entities by page where each page has page_size # of rows using API call
				print(f'Getting all {num_pages} pages of entity data.')
				all_page_responses = []
				for page in tqdm(range(1, num_pages + 1)):
					all_page_responses.append(get_entity_by_page(project, workspace, entity_type, page, page_size))

				# for each response(page) in all_page_responses[] - contains parameter metadata
				print(f'Writing {entity_count} attributes to tsv file.')
				for page_response in tqdm(all_page_responses):
					# for each set of attributes in results (no parameters) get attribute names and entity_id(name)
					for entity_json in page_response["results"]:
						attributes = entity_json["attributes"]
						name = entity_json["name"]
						# add name and value to dictionary of attributes
						attributes[entity_id] = name

						values = []
						# for each attribute(column name) in list of attribute names(all columns for entity)
						for attribute_name in attribute_names:
							value = ""
							# if entity's attribute(column) is in list of attributes from response, set response's attribute value
							if attribute_name in attributes:
								value = attributes[attribute_name]

							values.append(str(value))

						tsvout.write(",".join(values) + "\n")
						row_num += 1

			print(f'Finished exporting {entity_type}(s) to tsv with name {tsv_name}.')

			if drop_entity.lower() == "yes":
				with open(tsv_name, "r") as tsvin:
					lines = tsvin.readlines()

				with open(tsv_name, "w") as tsvout:
					for line in lines:
						columns = line.split(',')
						tsvout.write(','.join(columns[1:]))

		if __name__ == '__main__':
			main(
				project = "~{project_name}",
				workspace = "~{workspace_name}",
				entity_type = "~{table_name}",
				tsv_name = "~{table_data_filename}",
				page_size = "~{page_size}",
				attr_list = "~{dashboard_columns}",
				drop_entity = "~{drop_entity_name_column}"
			)
		CODE

		gsutil cp ~{table_data_filename} ~{dashboard_data_dir}/~{table_data_filename}
	>>>

	output {
		File table_csv = "~{table_data_filename}"
	}

	runtime {
		docker: docker
		memory: memory + " GB"
		cpu: cpu
		disks:  "local-disk " + disk_size + " SSD"
		disk: disk_size + " GB"
		preemptible: 0
	}

}