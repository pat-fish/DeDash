import { MapPinIcon } from '@heroicons/react/24/outline';

export default function Loc() {
    return (
        <div className="flex items-center gap-1">
            <MapPinIcon className="h-6 w-6 text-black" />
            <p className="text-black font-medium">Boston, MA</p>
        </div>
    );
}