# data_processor.py

import psycopg2
from psycopg2.extras import execute_values
import json
import re

class DataProcessor:
    def __init__(self, source_db_config, target_db_config):
        self.source_db_config = source_db_config
        self.target_db_config = target_db_config

    def connect_to_db(self, config):
        return psycopg2.connect(**config)

    def get_preprocessed_reports(self):
        conn = self.connect_to_db(self.source_db_config)
        cursor = conn.cursor()
        try:
            cursor.execute("""
                SELECT DISTINCT r.report_name, r.report_date
                FROM raw_egypt_weekly_reports r
                JOIN preprocessed_egypt_weekly_data p
                ON r.report_name = p.report_name AND r.report_date = p.report_date
                WHERE r.preprocessed = TRUE
                ORDER BY r.report_date DESC, r.report_name
            """)
            return cursor.fetchall()
        finally:
            cursor.close()
            conn.close()

    def get_preprocessed_sheets(self, report_name, report_date):
        conn = self.connect_to_db(self.source_db_config)
        cursor = conn.cursor()
        try:
            cursor.execute("""
                SELECT DISTINCT sheet_name
                FROM preprocessed_egypt_weekly_data
                WHERE report_name = %s AND report_date = %s
                ORDER BY sheet_name
            """, (report_name, report_date))
            return cursor.fetchall()
        finally:
            cursor.close()
            conn.close()

    def select_report_and_sheet(self):
        reports = self.get_preprocessed_reports()
        if not reports:
            print("No preprocessed reports available.")
            return None, None

        print("Available preprocessed reports:")
        for i, (report_name, report_date) in enumerate(reports, 1):
            print(f"{i}. {report_name} - {report_date}")
        
        while True:
            try:
                selection = int(input("Enter the number of the report to process (or 0 to exit): "))
                if selection == 0:
                    return None, None
                if 1 <= selection <= len(reports):
                    selected_report = reports[selection - 1]
                    break
                print("Invalid selection. Please try again.")
            except ValueError:
                print("Please enter a valid number.")
        
        sheets = self.get_preprocessed_sheets(*selected_report)
        if not sheets:
            print(f"No preprocessed sheets available for the selected report.")
            return None, None

        print("\nAvailable preprocessed sheets:")
        for i, (sheet_name,) in enumerate(sheets, 1):
            print(f"{i}. {sheet_name}")
        print(f"{len(sheets) + 1}. All sheets")
        
        while True:
            try:
                selection = int(input("Enter the number of the sheet to process (or select 'All sheets'): "))
                if 1 <= selection <= len(sheets):
                    selected_sheets = [sheets[selection - 1][0]]
                    break
                elif selection == len(sheets) + 1:
                    selected_sheets = [sheet[0] for sheet in sheets]
                    break
                print("Invalid selection. Please try again.")
            except ValueError:
                print("Please enter a valid number.")
        
        return selected_report, selected_sheets

    def fetch_preprocessed_data(self, report_name, report_date, sheet_name):
        conn = self.connect_to_db(self.source_db_config)
        cursor = conn.cursor()
        try:
            cursor.execute("""
                SELECT *
                FROM preprocessed_egypt_weekly_data
                WHERE report_name = %s AND report_date = %s AND sheet_name = %s
            """, (report_name, report_date, sheet_name))
            columns = [desc[0] for desc in cursor.description]
            return [dict(zip(columns, row)) for row in cursor.fetchall()]
        finally:
            cursor.close()
            conn.close()

    def check_jcn_twcode(self, record):
        jcn = record.get('jcn')
        twcode = record.get('twcode')
        
        if not jcn or not twcode:
            return False
        
        jcn_pattern = r'^[A-Z0-9-]+$'
        twcode_pattern = r'^[A-Z0-9]+$'
        
        return bool(re.match(jcn_pattern, jcn)) and bool(re.match(twcode_pattern, twcode))

    def check_suffix(self, record):
        additional_data = json.loads(record.get('additional_data', '{}'))
        return additional_data.get('suffix') is not None

    def check_details_match(self, record):
        critical_fields = ['nomenclature', 'niin', 'part_no', 'apl', 'cog', 'fsc', 'quantity', 'ui']
        return all(record.get(field) for field in critical_fields)

    def check_duplicates(self, records):
        seen = set()
        duplicates = {}
        for record in records:
            key = (record['jcn'], record['twcode'])
            if key in seen:
                duplicates[record['preprocessed_id']] = True
            seen.add(key)
        return duplicates

    def calculate_scores(self, check_results):
        scores = []
        for result in check_results:
            overall_score = sum([
                result['jcn_twcode_valid'],
                not result['suffix_check_result'],
                result['details_match_result'],
                not result['has_duplicates']
            ]) / 4 * 100
            
            scores.append({
                'overall_quality_score': overall_score,
                'data_integrity_score': (result['jcn_twcode_valid'] + not result['suffix_check_result']) / 2 * 100,
                'consistency_score': result['details_match_result'] * 100,
                'completeness_score': (not result['has_duplicates']) * 100
            })
        return scores

    def update_quality_checked_records(self, check_results):
        conn = self.connect_to_db(self.source_db_config)
        cursor = conn.cursor()
        try:
            execute_values(cursor, """
                INSERT INTO quality_checked_records
                (preprocessed_id, overall_quality_score, data_integrity_score, consistency_score, 
                completeness_score, jcn_twcode_valid, suffix_check_result, details_match_result, 
                has_duplicates, check_details)
                VALUES %s
                ON CONFLICT (preprocessed_id) DO UPDATE SET
                    overall_quality_score = EXCLUDED.overall_quality_score,
                    data_integrity_score = EXCLUDED.data_integrity_score,
                    consistency_score = EXCLUDED.consistency_score,
                    completeness_score = EXCLUDED.completeness_score,
                    jcn_twcode_valid = EXCLUDED.jcn_twcode_valid,
                    suffix_check_result = EXCLUDED.suffix_check_result,
                    details_match_result = EXCLUDED.details_match_result,
                    has_duplicates = EXCLUDED.has_duplicates,
                    check_details = EXCLUDED.check_details,
                    last_updated_at = CURRENT_TIMESTAMP
            """, [
                (
                    result['preprocessed_id'],
                    result['overall_quality_score'],
                    result['data_integrity_score'],
                    result['consistency_score'],
                    result['completeness_score'],
                    result['jcn_twcode_valid'],
                    result['suffix_check_result'],
                    result['details_match_result'],
                    result['has_duplicates'],
                    json.dumps(result['check_details'])
                ) for result in check_results
            ])
            conn.commit()
        except Exception as e:
            conn.rollback()
            print(f"Error updating quality checked records: {e}")
        finally:
            cursor.close()
            conn.close()

    def process_sheet(self, report_name, report_date, sheet_name):
        records = self.fetch_preprocessed_data(report_name, report_date, sheet_name)
        check_results = []

        for record in records:
            result = {
                'preprocessed_id': record['preprocessed_id'],
                'jcn_twcode_valid': self.check_jcn_twcode(record),
                'suffix_check_result': self.check_suffix(record),
                'details_match_result': self.check_details_match(record),
            }
            check_results.append(result)

        duplicate_check = self.check_duplicates(records)
        for result in check_results:
            result['has_duplicates'] = duplicate_check.get(result['preprocessed_id'], False)

        scores = self.calculate_scores(check_results)
        for result, score in zip(check_results, scores):
            result.update(score)
            result['check_details'] = {
                'jcn_twcode_check': "Valid" if result['jcn_twcode_valid'] else "Invalid",
                'suffix_check': "Needs review" if result['suffix_check_result'] else "OK",
                'details_match': "Matched" if result['details_match_result'] else "Mismatched",
                'duplicate_status': "Duplicate found" if result['has_duplicates'] else "No duplicates"
            }

        self.update_quality_checked_records(check_results)
        print(f"Processed {len(check_results)} records for {sheet_name}")
        return check_results

    def export_to_external_db(self, data):
        conn = self.connect_to_db(self.target_db_config)
        cursor = conn.cursor()
        try:
            cursor.execute("BEGIN")
            
            insert_data = []
            for row in data:
                insert_data.append((
                    row['preprocessed_id'],
                    row['raw_data_id'],
                    row['report_name'],
                    row['report_date'],
                    row['sheet_name'],
                    row['original_line'],
                    row['system_identifier_code'],
                    row['jcn'],
                    row['twcode'],
                    row['nomenclature'],
                    row['cog'],
                    row['fsc'],
                    row['niin'],
                    row['part_no'],
                    row['qty'],
                    row['ui'],
                    row['market_research_up'],
                    row['market_research_ep'],
                    row['availability_identifier'],
                    row['request_date'],
                    row['rdd'],
                    row['pri'],
                    row['swlin'],
                    row['hull_or_shop'],
                    row['suggested_source'],
                    row['mfg_cage'],
                    row['apl'],
                    row['nha_equipment_system'],
                    row['nha_model'],
                    row['nha_serial'],
                    row['techmanual'],
                    row['dwg_pc'],
                    row['requestor_remarks'],
                    row['shipdoc_tcn'],
                    row['v2x_ship_no'],
                    row['booking'],
                    row['vessel'],
                    row['container'],
                    row['carrier'],
                    row['sail_date'],
                    row['edd_to_ches'],
                    row['edd_egypt'],
                    row['rcd_v2x_date'],
                    row['lot_id'],
                    row['triwall'],
                    row['lsc_on_hand_date'],
                    row['arr_lsc_egypt'],
                    row['milstrip_req_no'],
                    row['additional_data'],
                    row['overall_quality_score'],
                    row['flags'],
                    row['data_integrity_score'],
                    row['consistency_score'],
                    row['completeness_score'],
                    row['check_details'],
                    row['mapped_fields']
                ))

            execute_values(cursor, """
                INSERT INTO staged_egypt_weekly_data
                (preprocessed_id, raw_data_id, report_name, report_date, sheet_name, original_line,
                system_identifier_code, jcn, twcode, nomenclature, cog, fsc, niin, part_no, qty, ui,
                market_research_up, market_research_ep, availability_identifier, request_date, rdd,
                pri, swlin, hull_or_shop, suggested_source, mfg_cage, apl, nha_equipment_system,
                nha_model, nha_serial, techmanual, dwg_pc, requestor_remarks, shipdoc_tcn,
                v2x_ship_no, booking, vessel, container, carrier, sail_date, edd_to_ches,
                edd_egypt, rcd_v2x_date, lot_id, triwall, lsc_on_hand_date, arr_lsc_egypt,
                milstrip_req_no, additional_data, overall_quality_score, flags,
                data_integrity_score, consistency_score, completeness_score, check_details,
                mapped_fields)
                VALUES %s
            """, insert_data)

            cursor.execute("COMMIT")
            print(f"Successfully exported {len(data)} records to ExtLogDB")
        except Exception as e:
            cursor.execute("ROLLBACK")
            print(f"Error exporting to ExtLogDB: {str(e)}")
        finally:
            cursor.close()
            conn.close()

	def export_and_cleanup(self, report_name, report_date, sheet_name):
			conn = self.connect_to_db(self.source_db_config)
			cursor = conn.cursor()
			try:
				cursor.execute("BEGIN")

				# Fetch data
				cursor.execute("""
					SELECT p.*, q.overall_quality_score, q.data_integrity_score, 
						   q.consistency_score, q.completeness_score, q.check_details
					FROM preprocessed_egypt_weekly_data p
					LEFT JOIN quality_checked_records q ON p.preprocessed_id = q.preprocessed_id
					WHERE p.report_name = %s AND p.report_date = %s AND p.sheet_name = %s
				""", (report_name, report_date, sheet_name))
				
				data = cursor.fetchall()
				columns = [desc[0] for desc in cursor.description]
				data = [dict(zip(columns, row)) for row in data]

				# Export data
				self.export_to_external_db(data)

				# Cleanup
				cursor.execute("""
					DELETE FROM preprocessed_egypt_weekly_data
					WHERE report_name = %s AND report_date = %s AND sheet_name = %s
				""", (report_name, report_date, sheet_name))
				
				cursor.execute("""
					DELETE FROM quality_checked_records
					WHERE preprocessed_id IN (
						SELECT preprocessed_id
						FROM preprocessed_egypt_weekly_data
						WHERE report_name = %s AND report_date = %s AND sheet_name = %s
					)
				""", (report_name, report_date, sheet_name))
				
				cursor.execute("""
					UPDATE raw_egypt_weekly_reports
					SET processed = TRUE, exported = TRUE
					WHERE report_name = %s AND report_date = %s AND sheet_name = %s
				""", (report_name, report_date, sheet_name))
				
				cursor.execute("COMMIT")
				print(f"Successfully exported and cleaned up data for report {report_name} dated {report_date}, sheet {sheet_name}")
			except Exception as e:
				cursor.execute("ROLLBACK")
				print(f"Error in export and cleanup process: {str(e)}")
			finally:
				cursor.close()
				conn.close()

		def process_report(self):
			selected_report, selected_sheets = self.select_report_and_sheet()
			if selected_report is None or selected_sheets is None:
				print("No report or sheets selected. Exiting.")
				return

			report_name, report_date = selected_report

			for sheet_name in selected_sheets:
				print(f"Processing sheet: {sheet_name}")
				check_results = self.process_sheet(report_name, report_date, sheet_name)
				self.export_and_cleanup(report_name, report_date, sheet_name)

			print("Processing completed.")

	# Usage
	if __name__ == "__main__":
		source_db_config = {
			"dbname": "ReportsDB",
			"user": "postgres",
			"password": "123456",
			"host": "cmms-db-01",
			"port": "5432"
		}
		target_db_config = {
			"dbname": "Beta_004",
			"user": "postgres",
			"password": "123456",
			"host": "cmms-db-01",
			"port": "5432"
		}
		processor = DataProcessor(source_db_config, target_db_config)
		processor.process_report()