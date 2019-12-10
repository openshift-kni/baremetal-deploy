#!/usr/bin/env python

import jinja2
import yaml
import sys
import argparse
import os
import base64
import random
from typing import NoReturn, Text

TEMPLATE_DIR = os.path.dirname(sys.argv[0]) + '/../templates/'


class BondingTemplator(object):

    def __init__(self, templates_dir: str):
        self.__templates_dir = templates_dir
        self.__iface_templ = 'ifcfg-iface.j2'
        self.__vlan_templ = 'ifcfg-bondX.vlan.j2'
        self.__bond_templ = 'ifcfg-bondX.j2'
        self.__ign_templ = 'bondX-ignition.j2'
        self.__nmstate_templ = 'nmstate-bondX.yaml.j2'
        try:
            self.__env = jinja2.Environment(
                loader=jinja2.FileSystemLoader(self.__templates_dir),
                keep_trailing_newline=True
            )
        except jinja2.TemplateError as e:
            print(
                "error loading templates directory",
                self.__templates_dir, ":", e)
            sys.exit(1)

    def __process_phy_devices(
            self, phy_devices: list, bond_device: str) -> list:
        results = list()
        for dev in phy_devices:
            try:
                dev['bond_device'] = bond_device
                template = self.__env.get_template(self.__iface_templ)
                output = template.render(dev)
                dev['b64'] = base64.b64encode(
                    output.encode('utf-8')).decode('utf-8')
                dev['filename'] = 'ifcfg-' + dev.get('device')
                results.append(dev)
            except jinja2.TemplateError as e:
                print("error processing", self.__iface_templ, ":", e)
                sys.exit(1)
        return results

    def __process_vlans(
            self, vlans: list, bond_device: str) -> list:
        results = list()
        for vlan in vlans:
            try:
                vlan['bond_device'] = bond_device
                template = self.__env.get_template(self.__vlan_templ)
                output = template.render(vlan)
                vlan['b64'] = base64.b64encode(
                    output.encode('utf-8')).decode('utf-8')
                vlan['filename'] = 'ifcfg-' + vlan.get('bond_device') + '.' \
                    + str(vlan.get('id'))
                del(vlan['bond_device'])
                results.append(vlan)
            except jinja2.TemplateError as e:
                print("error processing", self.__vlan_templ, ":", e)
                sys.exit(1)
        return results

    def __generate_ifcfg_files(self, template_data: dict) -> dict:
        try:
            bond_templ = self.__env.get_template(self.__bond_templ)
            bond_output = bond_templ.render(template_data)
        except jinja2.TemplateError as e:
            print("error processing", self.__bond_templ, ":", e)
            sys.exit(1)

        bond_device = template_data.get('device')
        template_data['b64'] = base64.b64encode(
            bond_output.encode('utf-8')).decode('utf-8')
        template_data['filename'] = 'ifcfg-' + template_data.get('device')

        phy_devices = template_data.get('phy_devices')
        template_data['phy_devices'] = self.__process_phy_devices(
            phy_devices, bond_device)

        vlans = template_data.get('vlans')
        template_data['vlans'] = self.__process_vlans(vlans, bond_device)
        return template_data

    def __render_ignition(self, parameters: dict) -> Text:
        try:
            template = self.__env.get_template(self.__ign_templ)
            return template.render(parameters)
        except jinja2.TemplateError as e:
            print("error processing", self.__ign_templ, ":", e)
            sys.exit(1)

    def __render_nmstate(self, parameters: dict) -> Text:
        try:
            template = self.__env.get_template(self.__nmstate_templ)
            return template.render(parameters)
        except jinja2.TemplateError as e:
            print("error processing", self.__nmstate_templ, ":", e)
            sys.exit(1)

    def __write_template_to_file(self, data: Text, outfile: str) -> NoReturn:
        try:
            with open(outfile, 'w') as file:
                file.write(data)
            return
        except OSError as e:
            print("Error writing", outfile, ":", e)
            sys.exit(1)

    def write_nmstate_to_file(self, data: Text, outdir: str) -> NoReturn:
        outfile = outdir + '/' + str(random.randint(1, 10000)) + \
            '-nmstate-bonding-manifest.yaml'
        self.__write_template_to_file(data, outfile)

    def write_ignition_to_file(self, data: Text, outdir: str) -> NoReturn:
        outfile = outdir + '/' + str(random.randint(1, 10000)) + \
            '-ignition-bond.ign'
        self.__write_template_to_file(data, outfile)

    def read_parameters_file(self, params_file: str) -> dict:
        try:
            with open(params_file) as file:
                parameters = yaml.load(file, Loader=yaml.FullLoader)
                return parameters
        except yaml.YAMLError as e:
            print('error parsing parameters file:', e)
            sys.exit(-1)

    def generate_ignition(self, params: dict) -> Text:
        primary = params.get('primary')
        if not primary:
            print('No primary bond data found')
            sys.exit(1)

        processed_data = self.__generate_ifcfg_files(primary)
        return self.__render_ignition(processed_data)

    def generate_nmstate(self, params: dict) -> Text:
        secondary = params.get('secondary')
        if not secondary:
            print('No secondary bond data found')
            sys.exit(1)

        return self.__render_nmstate(secondary)

    def generate_all(self, params: dict) -> dict:
        result = dict()
        result['ignition'] = self.generate_ignition(params)
        result['nmstate'] = self.generate_nmstate(params)
        return result


def main() -> NoReturn:
    parser = argparse.ArgumentParser(
        description="Generate bonding configuration files.",
        epilog="One of the three available modes is \
            required, all, ignition or nmstate")

    group = parser.add_mutually_exclusive_group()
    group.add_argument('-i', '--ignition', default=False, action='store_true',
                       help='mode Ignition, creates only Ignition file')
    group.add_argument('-n', '--nmstate', default=False, action='store_true',
                       help='mode NMState, create only NMState file')
    group.add_argument('-a', '--all', default=False, action='store_true',
                       help='mode all, create Ignition and NMState files')
    parser.add_argument('-f', '--param-file', required=True, type=str,
                        help='path to parameters file')
    parser.add_argument('-o', '--output-dir', default='out', type=str)
    parser.add_argument('-t', '--templates', default=TEMPLATE_DIR, type=str,
                        help='path to the templates directory')
    args = parser.parse_args()

    if not (args.ignition or args.nmstate or args.all):
        parser.print_help()
        sys.exit(1)

    if not os.path.isdir(args.output_dir):
        os.mkdir(args.output_dir)

    if not os.path.isdir(args.templates):
        print('Could not locate templates dir', args.templates)
        sys.exit(1)

    bonding = BondingTemplator(args.templates)

    params = bonding.read_parameters_file(args.param_file)

    if args.ignition:
        contents = bonding.generate_ignition(params)
        bonding.write_ignition_to_file(contents, args.output_dir)
    elif args.nmstate:
        contents = bonding.generate_nmstate(params)
        bonding.write_nmstate_to_file(contents, args.output_dir)
    else:
        result = bonding.generate_all(params)
        bonding.write_ignition_to_file(result.get('ignition'), args.output_dir)
        bonding.write_nmstate_to_file(result.get('nmstate'), args.output_dir)

    sys.exit(0)


if __name__ == '__main__':
    main()
